# frozen_string_literal: true

module ESPHome
  module Cli
    module Entities
      class Form < Entity
        def initialize(...)
          super

          @max_length = length_range&.end || 10
          @field = Curses::Field.new(1, @max_length, 0, 0, 0, 0)
          @field.set_back(Curses::A_UNDERLINE)
          @field.opts_off(Curses::O_AUTOSKIP)
          @form = Curses::Form.new([@field])

          extra_length = suffix ? suffix.length + 1 : 0
          @win = Curses::Window.new(3,
                                    @max_length + 4 + extra_length,
                                    index + Monitor::HEADER_ROWS,
                                    cli.name_width + 3)
          @win.keypad = true
          @form.set_win(@win)
          @form.set_sub(@win.derwin(1, @max_length, 1, 2))
        end

        def length_range
          0..10
        end

        def suffix = nil

        def activate
          @form.post
          if suffix
            @win.setpos(1, @max_length + 3)
            @win.addstr(suffix)
          end
          @win.setpos(1, 2)
          @win.box(0, 0)

          loop do
            case (ch = @win.getch)

            when Curses::KEY_RIGHT
              @form.driver(Curses::REQ_NEXT_CHAR)
            when Curses::KEY_LEFT
              @form.driver(Curses::REQ_PREV_CHAR)
            when Curses::KEY_BACKSPACE
              @form.driver(Curses::REQ_DEL_PREV)
            when "\n".ord
              @form.driver(Curses::REQ_VALIDATION)
              value = @field.buffer(0).strip
              break if value.empty?

              command(value)
              break
            when 27 # Esc
              break
            else
              @form.driver(ch)
            end
          rescue Curses::RequestDeniedError, Curses::UnknownCommandError
            next
          end
          @form.unpost
        end
      end
    end
  end
end
