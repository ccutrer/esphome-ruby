# frozen_string_literal: true

require_relative "menu"

module ESPHome
  module Cli
    module Entities
      module FormPrompt
        private

        def prompt_form(title, initial_value:, suffix:, field_width:)
          field, form, win = build_form_dialog(title, suffix, field_width)
          return unless win

          field.set_buffer(0, initial_value) if initial_value
          form.post
          win.box(0, 0)
          win.setpos(0, 2)
          safe_addstr(win, " #{title} ")
          if suffix
            win.setpos(1, field_width + 3)
            safe_addstr(win, suffix)
          end
          win.setpos(1, 2)
          win.refresh

          loop do
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
              return nil if value.empty?

              return value
            when 27, Curses::KEY_RESIZE
              return nil
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

        def build_form_dialog(title, suffix, field_width)
          width = field_width + 4 + (suffix ? suffix.length + 1 : 0)
          win = build_dialog_window(3, width, title)
          return [nil, nil, nil] unless win

          field = Curses::Field.new(1, field_width, 0, 0, 0, 0)
          field.set_back(Curses::A_UNDERLINE)
          field.opts_off(Curses::O_AUTOSKIP)
          form = Curses::Form.new([field])
          form.set_win(win)
          form.set_sub(win.derwin(1, field_width, 1, 2))
          [field, form, win]
        end
      end

      class Form < Entity
        include MenuPrompt
        include FormPrompt

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
          value = prompt_form(form_title,
                              initial_value:,
                              suffix:,
                              field_width:)
          command(value) if value
        end

        private

        def form_title
          name
        end

        def field_width
          @max_length
        end
      end
    end
  end
end
