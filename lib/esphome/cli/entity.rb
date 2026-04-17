# frozen_string_literal: true

require "delegate"

module ESPHome
  module Cli
    class Entity < SimpleDelegator
      attr_reader :cli, :index

      def initialize(cli, entity, index)
        super(entity)

        @cli = cli
        @index = index
        touch
      end

      def touch = @last_update = Time.now

      def print(win, clear_line: true, active: false)
        row = @index + Monitor::HEADER_ROWS
        return if row >= win.maxy

        win.setpos(row, 0)
        win.clrtoeol if clear_line
        safe_addstr(win, "#{name.ljust(cli.name_width)} : ")
        state = formatted_state
        if active
          win.attron(Curses::A_REVERSE) { safe_addstr(win, state) }
        else
          safe_addstr(win, state)
        end

        return unless __getobj__.is_a?(ESPHome::Entity::HasState)

        timestamp = "[#{@last_update.strftime("%H:%M:%S.%L")}]"
        return if timestamp.length >= win.maxx

        pos = [win.cury, win.curx]
        win.setpos(row, win.maxx - timestamp.length)
        safe_addstr(win, timestamp)
        win.setpos(*pos) if pos[1] < win.maxx
      rescue Curses::Error
        nil
      end

      private

      def safe_addstr(win, string)
        return if string.nil? || string.empty?

        remaining = win.maxx - win.curx
        return if remaining <= 0

        win.addstr(string[0, remaining])
      end
    end
  end
end

require_relative "entities/button"
require_relative "entities/cover"
require_relative "entities/date"
require_relative "entities/date_time"
require_relative "entities/lock"
require_relative "entities/number"
require_relative "entities/select"
require_relative "entities/switch"
require_relative "entities/text"
require_relative "entities/time"
