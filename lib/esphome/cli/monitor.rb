# frozen_string_literal: true

ENV["ESCDELAY"] = "0"
require "curses"

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

      attr_reader :name_width
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
            entity_wrapper.print(@win, active: @current_entity == entity_wrapper.index) unless @sub_active
          elsif entity_or_log_line.is_a?(Action)
            logger.info(entity_or_log_line.inspect)
          else
            logger.warn("Unexpected message #{entity_or_log_line.inspect}")
          end
          next if !@win || @sub_active

          @win.refresh
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
          rebuild_logwin if @logwin

          @current_entity = @entities.index { |e| e.respond_to?(:activate) } || -1
          render_all

          @device.stream_states
          @device.stream_actions if @actions
          @device.stream_log(dump_config: @dump_config) if @device.device_logger.level < Logger::FATAL
        end

        @device.on_disconnect do
          logger.info("Gracefully disconnected")
          reconnect
        end

        @device.connect

        begin
          Thread.new do
            @device.loop
          rescue IOError, SocketError, SystemCallError, Timeout::Error => e
            logger.warn("Connection lost: #{e}")
            @device.disconnect
            reconnect
            retry
          rescue => e
            logger.error("UNHANDLED EXCEPTION: #{e}", render: false)
            e.backtrace.each do |line|
              logger.error("  #{line}", render: false)
            end
            render_log
            retry
          end

          loop do
            case @win.getch
            when Curses::Key::UP
              new_entity = @entities.reverse.find { |e| e.index < @current_entity && e.respond_to?(:activate) }&.index
              next unless new_entity

              @entities[@current_entity].print(@win)
              @current_entity = new_entity
              @entities[@current_entity].print(@win, active: true)
              @win.refresh
            when Curses::Key::DOWN
              new_entity = @entities.find { |e| e.index > @current_entity && e.respond_to?(:activate) }&.index
              next unless new_entity

              @entities[@current_entity].print(@win)
              @current_entity = new_entity
              @entities[@current_entity].print(@win, active: true)
              @win.refresh
            when "\n".ord
              entity_wrapper = @entities[@current_entity]
              if entity_wrapper.respond_to?(:activate)
                @sub_active = true
                entity_wrapper.activate
                @sub_active = false
                render_all
              end
            when 27 # Esc
              break
            end
          end
        rescue Interrupt
          # exitting
        ensure
          Curses.close_screen
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
        @log_lines << log_line
        @log_lines.shift if @log_lines.size > [20, log_area_height].max

        puts log_line unless @win
        render_log if render && @win && !@sub_active
      end
      alias_method :log, :add

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
      end

      def log_area_height
        return 20 unless @win

        @win.maxy - @entities.size - 4
      end

      def render_log
        @logwin.clear
        @logwin.setpos(0, 0)

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

        @logwin.refresh
      end

      def rebuild_logwin
        @logwin&.close
        @logwin = @win.subwin(log_area_height, @win.maxx, @entities.size + 4, 0)
        @logwin.scrollok(true)
      end

      def render_all
        unless @win
          unless @winch_trapped
            @winch_trapped = true
            Signal.trap(:WINCH) do
              Curses.close_screen
              @win = nil
              render_all
            end
          end

          @win = Curses.init_screen
          Curses.noecho
          Curses.start_color
          Curses.use_default_colors
          @win.keypad = true
          rebuild_logwin
          Colors::ANSI_COLOR_MAP.each_value do |color|
            Curses.init_pair(color + 1, color, -1)
          end
        end

        @win.clear

        @win.setpos(0, 0)
        @win.addstr("ESPHome")
        @win.setpos(1, 0)
        @win.addstr("#{@device.friendly_name.ljust(47)} #{@device.esphome_version} - #{@device.compilation_time}")
        @win.setpos(2, 0)
        @win.addstr("=" * 80)

        @entities.each do |entity|
          entity.print(@win, clear_line: false, active: @current_entity == entity.index)
        end

        render_log

        @win.refresh
      end

      def reconnect
        @device.connect
      rescue IOError, SocketError, SystemCallError, Timeout::Error => e
        logger.warn("Failed to reconnect: #{e}")
        sleep 1
        retry
      end
    end
  end
end
