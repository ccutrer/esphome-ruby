# frozen_string_literal: true

module ESPHome
  module Cli
    module Entities
      class Menu < Entity
        def activate
          menu, win = build_menu
          return unless win

          menu.post
          win.box(0, 0)

          loop do
            break if cli.resize_pending?

            case win.getch
            when Curses::Key::DOWN
              menu.driver(Curses::REQ_NEXT_ITEM)
            when Curses::Key::UP
              menu.driver(Curses::REQ_PREV_ITEM)
            when "\n".ord
              command(menu.current_item.name)
              break
            when 27, Curses::KEY_RESIZE # Esc
              break
            when nil
              next
            end
          rescue Curses::RequestDeniedError
            next
          end
        ensure
          menu&.unpost
          win&.close
        end

        private

        def build_menu
          root = cli.win
          return [nil, nil] unless root

          max_width = options.map(&:length).max
          width = max_width + 5
          height = options.length + 2
          return [nil, nil] if width > root.maxx || height > root.maxy

          top = (index + Monitor::HEADER_ROWS).clamp(0, root.maxy - height)
          left = (cli.name_width + 3).clamp(0, root.maxx - width)

          menu = Curses::Menu.new(options.map { |option| Curses::Item.new(option, "") })
          win = Curses::Window.new(height, width, top, left)
          win.keypad = true
          win.timeout = 100
          menu.set_win(win)
          menu.set_sub(win.derwin(options.length, max_width + 2, 1, 2))
          [menu, win]
        end
      end
    end
  end
end
