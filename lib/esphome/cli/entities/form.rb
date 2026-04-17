# frozen_string_literal: true

module ESPHome
  module Cli
    module Entities
      class Form < Entity
        def initialize(...)
          super

          @max_length = length_range&.end || 10
        end

        def length_range
          0..10
        end

        def suffix = nil

        def initial_value = nil

        def activate
          field, form, win = build_form
          return unless win

          field.set_buffer(0, initial_value) if initial_value

          form.post
          if suffix
            win.setpos(1, @max_length + 3)
            win.addstr(suffix)
          end
          win.setpos(1, 2)
          win.box(0, 0)

          loop do
            break if cli.resize_pending?

            case (ch = win.getch)
            when Curses::KEY_RIGHT
              form.driver(Curses::REQ_NEXT_CHAR)
            when Curses::KEY_LEFT
              form.driver(Curses::REQ_PREV_CHAR)
            when Curses::KEY_BACKSPACE
              form.driver(Curses::REQ_DEL_PREV)
            when "\n".ord
              form.driver(Curses::REQ_VALIDATION)
              value = field.buffer(0).strip
              break if value.empty?

              command(value)
              break
            when 27, Curses::KEY_RESIZE # Esc
              break
            when nil
              next
            else
              form.driver(ch)
            end
          rescue Curses::RequestDeniedError, Curses::UnknownCommandError
            next
          end
        ensure
          form&.unpost
          win&.close
        end

        private

        def build_form
          root = cli.win
          return [nil, nil, nil] unless root

          width = @max_length + 4 + (suffix ? suffix.length + 1 : 0)
          height = 3
          return [nil, nil, nil] if width > root.maxx || height > root.maxy

          top = (index + Monitor::HEADER_ROWS).clamp(0, root.maxy - height)
          left = (cli.name_width + 3).clamp(0, root.maxx - width)

          field = Curses::Field.new(1, @max_length, 0, 0, 0, 0)
          field.set_back(Curses::A_UNDERLINE)
          field.opts_off(Curses::O_AUTOSKIP)

          form = Curses::Form.new([field])
          win = Curses::Window.new(height, width, top, left)
          win.keypad = true
          win.timeout = 100
          form.set_win(win)
          form.set_sub(win.derwin(1, @max_length, 1, 2))
          [field, form, win]
        end
      end
    end
  end
end
