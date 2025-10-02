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
        win.setpos(@index + Monitor::HEADER_ROWS, 0)
        win.clrtoeol if clear_line
        win.addstr("#{name.ljust(cli.name_width)} : ")
        s = formatted_state
        if active
          win.attron(Curses::A_REVERSE)
          win.addstr(s)
          win.attroff(Curses::A_REVERSE)
        else
          win.addstr(s)
        end

        return unless __getobj__.is_a?(ESPHome::Entity::HasState)

        pos = win.cury, win.curx
        space = " " * [80 - cli.name_width - 3 - 14 - s.length, 1].max
        win.addstr("#{space}[#{@last_update.strftime("%H:%M:%S.%L")}]")
        win.setpos(*pos)
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
