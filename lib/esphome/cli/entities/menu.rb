# frozen_string_literal: true

module ESPHome
  module Cli
    module Entities
      module MenuPrompt
        private

        def prompt_menu(title, options, current = nil)
          content_width = options.map(&:length).max + 4
          win = build_dialog_window(options.length + 2, content_width, title)
          return unless win

          index = options.index(current) || 0
          loop do
            render_select_options(win, title, options, index)

            case win.getch
            when Curses::Key::UP
              index = (index - 1) % options.length
            when Curses::Key::DOWN
              index = (index + 1) % options.length
            when "\n".ord
              return options[index]
            when 27, Curses::KEY_RESIZE
              return nil
            when nil
              next
            end
          end
        ensure
          win&.close
        end

        def render_select_options(win, title, options, index)
          win.clear
          win.box(0, 0)
          win.setpos(0, 2)
          safe_addstr(win, " #{title} ")
          options.each_with_index do |option, idx|
            win.setpos(idx + 1, 2)
            if idx == index
              win.attron(Curses::A_REVERSE) { safe_addstr(win, option) }
            else
              safe_addstr(win, option)
            end
          end
          win.refresh
        end

        def build_dialog_window(height, width, title)
          root = cli.win
          return unless root

          width = [width, title.length + 6].max
          return if width > root.maxx || height > root.maxy

          top = (index + Monitor::HEADER_ROWS).clamp(0, root.maxy - height)
          left = (cli.name_width + 3).clamp(0, root.maxx - width)
          win = Curses::Window.new(height, width, top, left)
          win.keypad = true
          win.timeout = 100
          win
        end
      end

      class Menu < Entity
        include MenuPrompt

        def activate
          choice = prompt_menu(menu_title, options)
          command(choice) if choice
        end

        private

        def menu_title
          name
        end
      end
    end
  end
end
