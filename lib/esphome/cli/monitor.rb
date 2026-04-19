# frozen_string_literal: true

ENV["ESCDELAY"] = "0"
require "curses"
require "io/console"

require "esphome"

require_relative "colors"
require_relative "entity"

module ESPHome
  module Cli
    class Monitor
      include Colors

      HEADER_ROWS = 3

      class LoggerWrapper < Logger
        def initialize(parent, level: Logger::DEBUG)
          super(IO::NULL, level:)

          @parent = parent
        end

        def add(severity, message = nil, progname = nil, ...)
          severity ||= UNKNOWN
          return true if severity < level

          @parent.add(severity, message, progname, ...)
        end
        alias_method :log, :add
      end
      private_constant :LoggerWrapper

      class << self
        def run(...)
          new(...).run
        end
      end

      attr_reader :name_width, :win
      attr_accessor :logger

      def initialize(device,
                     actions: false,
                     device_log_level: nil,
                     connection_log_level: nil,
                     log_level: nil,
                     dump_config: false)
        @device = device
        @win = nil
        @entities_by_key = {}
        @entities = []
        @log_lines = []
        @current_entity = -1
        @sub_active = false
        @name_width = 0
        @device.device_logger = LoggerWrapper.new(self, level: device_log_level || Logger::DEBUG)
        @device.connection_logger = LoggerWrapper.new(self, level: connection_log_level || Logger::WARN)
        @logger = LoggerWrapper.new(self, level: log_level || Logger::INFO)
        @actions = actions
        @dump_config = dump_config
        @winch_trapped = false
        @logwin = nil
        @screen_initialized = false
        @resize_pending = false
        @ui_events = Queue.new
        @log_mutex = Mutex.new
      end

      Logger::Severity.constants.each do |level|
        class_eval <<~RUBY, __FILE__, __LINE__ + 1
          def #{level.downcase}(msg = nil, ...)  # def warn(msg = nil, ...)
            add(Logger::#{level}, msg, ...)      #   add(Logger::WARN, msg, ...)
          end                                    # end
        RUBY
      end

      def run
        @device.on_message do |entity_or_log_line|
          if entity_or_log_line.respond_to?(:key) && (entity_wrapper = @entities_by_key[entity_or_log_line.key])
            entity_wrapper.touch
            queue_ui_event(:entity, entity_wrapper)
          elsif entity_or_log_line.is_a?(Action)
            logger.info(entity_or_log_line.inspect)
          else
            logger.warn("Unexpected message #{entity_or_log_line.inspect}")
          end
        end

        @device.on_connect do
          logger.info("Connected")
          @name_width = @device.entities.values.map { |e| e.name.length }.max || 0
          @entities_by_key = {}
          @entities = []
          @device.entities.values.sort_by(&:name).each_with_index do |entity, idx|
            simple_name = entity.class.name.split("::").last
            entity_class = if Entities.const_defined?(simple_name)
                             Entities.const_get(simple_name, false)
                           else
                             Entity
                           end
            entity_wrapper = entity_class.new(self, entity, idx)
            @entities_by_key[entity.key] = entity_wrapper
            @entities << entity_wrapper
          end

          @current_entity = @entities.index { |e| e.respond_to?(:activate) } || -1
          queue_ui_event(:render_all)

          @device.stream_states
          @device.stream_actions if @actions
          @device.stream_log(dump_config: @dump_config) if @device.device_logger.level < Logger::FATAL
        end

        @device.on_disconnect do
          logger.info("Gracefully disconnected")
          reconnect
        end

        install_winch_handler
        @device.connect
        ensure_screen
        process_ui_events

        begin
          Thread.new do
            @device.loop
          rescue IOError, SocketError, SystemCallError, Timeout::Error => e
            logger.warn("Connection lost: #{e}")
            @device.disconnect
            reconnect
            retry
          rescue => e
            error("UNHANDLED EXCEPTION: #{e}", render: false)
            e.backtrace.each do |line|
              error("  #{line}", render: false)
            end
            queue_ui_event(:log)
            retry
          end

          loop do
            process_ui_events

            case @win.getch
            when Curses::Key::UP
              new_entity = @entities.reverse.find { |e| e.index < @current_entity && e.respond_to?(:activate) }&.index
              next unless new_entity

              @entities[@current_entity]&.print(@win) if @current_entity >= 0
              @current_entity = new_entity
              @entities[@current_entity].print(@win, active: true)
              @win.refresh
            when Curses::Key::DOWN
              new_entity = @entities.find { |e| e.index > @current_entity && e.respond_to?(:activate) }&.index
              next unless new_entity

              @entities[@current_entity]&.print(@win) if @current_entity >= 0
              @current_entity = new_entity
              @entities[@current_entity].print(@win, active: true)
              @win.refresh
            when Curses::Key::LEFT
              next unless @current_entity >= 0

              @entities[@current_entity].move_left
              @entities[@current_entity].print(@win, active: true)
              @win.refresh
            when Curses::Key::RIGHT
              next unless @current_entity >= 0

              @entities[@current_entity].move_right
              @entities[@current_entity].print(@win, active: true)
              @win.refresh
            when "\n".ord
              entity_wrapper = @entities[@current_entity]
              activate_entity(entity_wrapper) if entity_wrapper.respond_to?(:activate)
            when 27 # Esc
              break
            when nil
              next
            end
          end
        rescue Interrupt
          # exiting
        ensure
          close_screen
        end
        @device.disconnect
      end

      def add(_level, message = nil, progname = nil, render: true)
        if message.nil?
          message = if block_given?
                      yield
                    else
                      progname
                    end
        end

        log_line = "[#{Time.now.strftime("%H:%M:%S.%L")}] #{message}"
        @log_mutex.synchronize do
          @log_lines << log_line
          @log_lines.shift if @log_lines.size > [20, log_area_height].max
        end

        puts log_line unless @screen_initialized
        queue_ui_event(:log) if render
      end
      alias_method :log, :add

      def resize_pending?
        @resize_pending
      end

      private

      def parse_ansi_and_render(line)
        @logwin.clrtoeol
        current_color = nil
        current_attr = Curses::A_NORMAL

        line.split(ANSI_ESCAPE_REGEX).each_with_index do |part, i|
          if i.odd?
            codes = part.split(";").map(&:to_i)
            current_color, current_attr = parse_sgr_codes(codes)
          elsif current_color
            pair_id = current_color + 1
            @logwin.attron(Curses.color_pair(pair_id) | current_attr) do
              @logwin.addstr(part)
            end
          else
            @logwin.attron(current_attr) do
              @logwin.addstr(part)
            end
          end
        end
      rescue Curses::Error
        nil
      end

      def log_area_height
        return 20 unless @win

        [@win.maxy - @entities.size - 4, 0].max
      end

      def render_log
        return unless @logwin

        @logwin.clear
        @logwin.setpos(0, 0)

        @log_mutex.synchronize do
          @log_lines.each_with_index do |log_line, idx|
            unless idx.zero?
              if @logwin.cury == @logwin.maxy - 1
                @logwin.scroll
                @logwin.setpos(@logwin.cury, 0)
              else
                @logwin.setpos(@logwin.cury + 1, 0)
              end
            end

            parse_ansi_and_render(log_line)
          end
        end

        @logwin.refresh
      rescue Curses::Error
        nil
      end

      def rebuild_logwin
        @logwin&.close
        @logwin = nil

        height = log_area_height
        return if height <= 0

        top = @entities.size + 4
        return if top >= @win.maxy

        @logwin = @win.subwin(height, @win.maxx, top, 0)
        @logwin.scrollok(true)
      rescue Curses::Error
        @logwin = nil
      end

      def render_all
        ensure_screen
        rebuild_logwin
        @win.clear

        safe_setpos(@win, 0, 0)
        safe_addstr(@win, "ESPHome")
        safe_setpos(@win, 1, 0)
        left_header = @device.friendly_name.to_s
        right_header = "#{@device.esphome_version} - #{@device.compilation_time}"
        safe_addstr(@win, left_header)
        if right_header.length < @win.maxx
          safe_setpos(@win, 1, @win.maxx - right_header.length)
          safe_addstr(@win, right_header)
        end
        safe_setpos(@win, 2, 0)
        safe_addstr(@win, "=" * @win.maxx)

        @entities.each do |entity|
          entity.print(@win, active: @current_entity == entity.index)
        end

        render_log

        @win.refresh
      end

      def ensure_screen
        return if @screen_initialized && @win

        @win = Curses.init_screen
        Curses.noecho
        Curses.start_color
        Curses.use_default_colors
        @win.keypad = true
        @win.timeout = 100
        Colors::ANSI_COLOR_MAP.each_value do |color|
          Curses.init_pair(color + 1, color, -1)
        end
        @screen_initialized = true
      end

      def close_screen
        return unless @screen_initialized

        @logwin&.close
        @logwin = nil
        Curses.close_screen
        @win = nil
        @screen_initialized = false
      end

      def install_winch_handler
        return if @winch_trapped

        @winch_trapped = true
        Signal.trap(:WINCH) do
          @resize_pending = true
        end
      end

      def process_ui_events
        if @resize_pending
          if @screen_initialized
            rows, cols = IO.console.winsize
            Curses.resizeterm(rows, cols)
            @win&.resize(rows, cols)
            @win&.clear
          else
            close_screen
          end
          @resize_pending = false
          queue_ui_event(:render_all)
        end

        render_all_needed = false
        log_dirty = false
        entity_updates = []

        loop do
          type, payload = @ui_events.pop(true)
          case type
          when :entity
            entity_updates << payload
          when :log
            log_dirty = true
          when :render_all
            render_all_needed = true
          end
        rescue ThreadError
          break
        end

        return if @sub_active

        if render_all_needed
          render_all
          return
        end

        return if entity_updates.empty? && !log_dirty

        ensure_screen
        entity_updates.uniq.each do |entity|
          entity.print(@win, active: @current_entity == entity.index)
        end
        render_log if log_dirty
        @win.refresh
      end

      def queue_ui_event(type, payload = nil)
        @ui_events << [type, payload]
      end

      def safe_setpos(window, row, column)
        return if row.negative? || row >= window.maxy || column.negative? || column >= window.maxx

        window.setpos(row, column)
      rescue Curses::Error
        nil
      end

      def safe_addstr(window, string)
        return if string.nil? || string.empty?

        remaining = window.maxx - window.curx
        return if remaining <= 0

        window.addstr(string[0, remaining])
      rescue Curses::Error
        nil
      end

      def reconnect
        @device.connect
      rescue IOError, SocketError, SystemCallError, Timeout::Error => e
        logger.warn("Failed to reconnect: #{e}")
        sleep 1
        retry
      end

      def activate_entity(entity_wrapper)
        @sub_active = true
        entity_wrapper.activate
        queue_ui_event(:render_all)
      ensure
        @sub_active = false
      end
    end
  end
end
