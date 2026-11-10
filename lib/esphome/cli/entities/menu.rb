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
            visible = dialog_fits?(win)
            render_select_options(win, title, options, index) if visible

            ch = (visible ? win : cli.win).getch
            if cli.resize_pending? || ch == Curses::KEY_RESIZE
              cli.resize_display
              position_dialog_window(win) if dialog_fits?(win)
              next if ch == Curses::KEY_RESIZE
            end

            case ch
            when Curses::Key::UP
              index = (index - 1) % options.length
            when Curses::Key::DOWN
              index = (index + 1) % options.length
            when "\n".ord
              return options[index]
            when 27
              return nil
            when nil
              next
            end
          end
        ensure
          win&.close
        end

        def dialog_fits?(win)
          win.maxx <= cli.win.maxx && win.maxy <= cli.win.maxy
        end

        def position_dialog_window(win)
          top = (index + Monitor::HEADER_ROWS).clamp(0, cli.win.maxy - win.maxy)
          left = (cli.name_width + 3).clamp(0, cli.win.maxx - win.maxx)
          win.move(top, left)
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

        def build_dialog_window(height, width, title, fit_width: false)
          root = cli.win
          return unless root

          width = [width, title.length + 6].max
          width = [width, root.maxx].min if fit_width
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
