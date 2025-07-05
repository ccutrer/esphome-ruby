# frozen_string_literal: true

module ESPHome
  module Cli
    module Entities
      class Menu < Entity
        def initialize(...)
          super

          max_width = options.map(&:length).max
          @menu = Curses::Menu.new(options.map { |option| Curses::Item.new(option, "") })
          @win = Curses::Window.new(options.length + 2,
                                    max_width + 5,
                                    index + Monitor::HEADER_ROWS,
                                    cli.name_width + 3)
          @win.keypad = true
          @menu.set_win(@win)

          @menu.set_sub(@win.derwin(options.length, max_width + 2, 1, 2))
        end

        def activate
          @menu.post
          @win.box(0, 0)

          loop do
            case @win.getch
            when Curses::Key::DOWN
              @menu.driver(Curses::REQ_NEXT_ITEM)
            when Curses::Key::UP
              @menu.driver(Curses::REQ_PREV_ITEM)
            when "\n".ord
              command(@menu.current_item.name)
              break
            when 27 # Esc
              break
            end
          rescue Curses::RequestDeniedError
            next
          end
          @menu.unpost
        end
      end
    end
  end
end
