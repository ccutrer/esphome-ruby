# frozen_string_literal: true

require_relative "menu"

module ESPHome
  module Cli
    module Entities
      module FormPrompt
        private

        def prompt_form(title, initial_value:, suffix:, field_width:)
          max_length = field_width
          available_width = cli.win&.maxx.to_i - 4 - (suffix ? suffix.length + 1 : 0)
          field_width = [field_width, available_width].min
          return if field_width <= 0

          field, form, win = build_form_dialog(title, suffix, field_width, max_length:)
          return unless win

          field.set_buffer(0, initial_value) if initial_value
          selected = initial_value && !initial_value.empty?
          field.set_fore(Curses::A_REVERSE) if selected
          field.set_back(Curses::A_UNDERLINE | Curses::A_REVERSE) if selected
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
            ch = win.getch
            if selected && (ch == Curses::KEY_LEFT || ch == Curses::KEY_RIGHT ||
                            ch == Curses::KEY_BACKSPACE || ch == Curses::KEY_DC ||
                            ch == 8 || ch == 127 || (ch.is_a?(String) && ch.match?(/[[:print:]]/)) ||
                            (ch.is_a?(Integer) && ch.between?(32, 255)))
              selected = false
              field.set_fore(Curses::A_NORMAL)
              field.set_back(Curses::A_UNDERLINE)
              case ch
              when Curses::KEY_LEFT
                form.driver(Curses::REQ_BEG_FIELD)
                next
              when Curses::KEY_RIGHT
                form.driver(Curses::REQ_END_FIELD)
                next
              else
                form.driver(Curses::REQ_CLR_FIELD)
                next if [Curses::KEY_BACKSPACE, Curses::KEY_DC, 8, 127].include?(ch)
              end
            end

            case ch
            when Curses::KEY_RIGHT
              form.driver(Curses::REQ_NEXT_CHAR)
            when Curses::KEY_LEFT
              form.driver(Curses::REQ_PREV_CHAR)
            when Curses::KEY_BACKSPACE, 8, 127
              form.driver(Curses::REQ_DEL_PREV)
            when Curses::KEY_DC
              form.driver(Curses::REQ_DEL_CHAR)
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

        def build_form_dialog(title, suffix, field_width, max_length: field_width)
          width = field_width + 4 + (suffix ? suffix.length + 1 : 0)
          win = build_dialog_window(3, width, title)
          return [nil, nil, nil] unless win

          field = Curses::Field.new(1, field_width, 0, 0, 0, 0)
          field.set_back(Curses::A_UNDERLINE)
          field.opts_off(Curses::O_AUTOSKIP)
          field.opts_off(Curses::O_BLANK)
          field.opts_off(Curses::O_STATIC)
          field.set_max(max_length)
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
