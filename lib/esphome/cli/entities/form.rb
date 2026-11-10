# frozen_string_literal: true

require_relative "menu"

module ESPHome
  module Cli
    module Entities
      module FormPrompt
        private

        def prompt_form(title, initial_value:, suffix:, field_width:)
          max_length = field_width
          field_width = form_field_width(suffix, max_length)
          return if field_width <= 0

          field, form, win, sub = build_form_dialog(title, suffix, field_width, max_length:)
          return unless win

          selected = initial_value && !initial_value.empty?
          post_form_dialog(field, form, win, title, suffix, field_width, initial_value, selected)

          loop do
            ch = (dialog_fits?(win) ? win : cli.win).getch
            if cli.resize_pending? || ch == Curses::KEY_RESIZE
              cli.resize_display
              new_width = form_field_width(suffix, max_length)
              width = [form_window_width(title, suffix, new_width), cli.win.maxx].min
              if new_width.positive? && cli.win.maxy >= 3 &&
                 (new_width != field_width || win.maxx != width || win.maxy != 3)
                form.driver(Curses::REQ_VALIDATION)
                value = field.buffer(0)
                cursor = form_cursor_position(form)
                form.unpost
                sub.close
                win.close
                field_width = new_width
                field, form, win, sub = build_form_dialog(title, suffix, field_width, max_length:)
                post_form_dialog(field, form, win, title, suffix, field_width, value, selected)
                cursor.times { form.driver(Curses::REQ_NEXT_CHAR) }
                win.refresh
              elsif dialog_fits?(win)
                position_dialog_window(win)
                sub.move(win.begy + 1, win.begx + 2)
                win.touch
                win.refresh
              end
              next if ch == Curses::KEY_RESIZE
            end

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
            when 27
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
          sub&.close
          win&.close
        end

        def form_field_width(suffix, max_length)
          [max_length, cli.win&.maxx.to_i - 4 - (suffix ? suffix.length + 1 : 0)].min
        end

        def form_cursor_position(form)
          position = 0
          loop do
            form.driver(Curses::REQ_PREV_CHAR)
            position += 1
          end
        rescue Curses::RequestDeniedError
          position
        end

        def post_form_dialog(field, form, win, title, suffix, field_width, value, selected)
          field.set_buffer(0, value) if value
          field.set_fore(selected ? Curses::A_REVERSE : Curses::A_NORMAL)
          field.set_back(Curses::A_UNDERLINE)
          form.post
          win.box(0, 0)
          win.setpos(0, 2)
          safe_addstr(win, " #{title} "[0, win.maxx - 4])
          if suffix
            win.setpos(1, field_width + 3)
            safe_addstr(win, suffix)
          end
          win.setpos(1, 2)
          win.refresh
        end

        def build_form_dialog(title, suffix, field_width, max_length: field_width)
          width = form_window_width(title, suffix, field_width)
          win = build_dialog_window(3, width, title, fit_width: true)
          return [nil, nil, nil] unless win

          field = Curses::Field.new(1, field_width, 0, 0, 0, 0)
          field.set_back(Curses::A_UNDERLINE)
          field.opts_off(Curses::O_AUTOSKIP)
          field.opts_off(Curses::O_BLANK)
          field.opts_off(Curses::O_STATIC)
          field.set_max(max_length)
          form = Curses::Form.new([field])
          form.set_win(win)
          sub = win.derwin(1, field_width, 1, 2)
          form.set_sub(sub)
          [field, form, win, sub]
        end

        def form_window_width(title, suffix, field_width)
          [field_width + 4 + (suffix ? suffix.length + 1 : 0), title.length + 6].max
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
