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

      class << self
        def run(...)
          new(...).run
        end
      end

      attr_reader :name_width

      def initialize(device)
        @device = device
        @win = Curses.stdscr
        @entities_by_key = {}
        @entities = []
        @log_lines = []
        @current_entity = -1
        @sub_active = false
        @name_width = 0
      end

      def run
        Signal.trap("SIGWINCH") do
          render_all
        end

        Curses.init_screen
        Curses.noecho
        Curses.start_color
        Curses.use_default_colors
        @win = Curses.stdscr
        @win.keypad = true
        Colors::ANSI_COLOR_MAP.each_value do |color|
          Curses.init_pair(color + 1, color, -1)
        end

        @device.on_message do |entity_or_log_line|
          if entity_or_log_line.is_a?(String)
            log(entity_or_log_line)

            render_log unless @sub_active
          elsif (entity_wrapper = @entities_by_key[entity_or_log_line.key])
            entity_wrapper.touch
            entity_wrapper.print(@win, active: @current_entity == entity_wrapper.index) unless @sub_active
          end
          next if @sub_active

          @win.refresh
        end

        @device.connect

        @name_width = @device.entities.values.map { |e| e.name.length }.max || 0
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

        begin
          render_all

          Thread.new do
            @device.stream_states
            @device.stream_log(dump_config: true)
            @device.loop
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
      end

      def log(message)
        @log_lines << "[#{Time.now.strftime("%H:%M:%S")}] #{message}"
        @log_lines.shift if @log_lines.size > [20, visible_lines].max
      end

      private

      def parse_ansi_and_render(line)
        @win.clrtoeol
        current_color = nil
        current_attr = Curses::A_NORMAL

        line.split(ANSI_ESCAPE_REGEX).each_with_index do |part, i|
          if i.odd?
            codes = part.split(";").map(&:to_i)
            current_color, current_attr = parse_sgr_codes(codes)
          elsif current_color
            pair_id = current_color + 1
            @win.attron(Curses.color_pair(pair_id) | current_attr) do
              @win.addstr(part)
            end
          else
            @win.attron(current_attr) do
              @win.addstr(part)
            end
          end
        end
      end

      def visible_lines
        @win.maxy - @entities.size - 5
      end

      def render_log
        visible_lines = self.visible_lines

        @log_lines.each_with_index do |log_line, idx|
          break if idx >= visible_lines

          @win.setpos(@entities.size + 4 + idx, 0)

          parse_ansi_and_render(log_line)
        end
      end

      def render_all
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
    end
  end
end
