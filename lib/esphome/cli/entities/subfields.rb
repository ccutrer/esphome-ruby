# frozen_string_literal: true

require_relative "menu"

module ESPHome
  module Cli
    module Entities
      class Subfields < Entity
        include MenuPrompt

        def initialize(...)
          super

          @selected_subfield = 0
        end

        def move_left
          return if subfields.size <= 1

          @selected_subfield = (@selected_subfield - 1) % subfields.size
        end

        def move_right
          return if subfields.size <= 1

          @selected_subfield = (@selected_subfield + 1) % subfields.size
        end

        def activate
          __send__(:"activate_#{active_subfield}")
        end

        private

        def print_state(win, active:)
          formatted_segments.each_with_index do |segment, idx|
            safe_addstr(win, " ") unless idx.zero?
            if active && idx == highlighted_segment_index
              prefix, value, suffix = highlighted_segment_parts(idx, segment)
              safe_addstr(win, prefix)
              win.attron(Curses::A_REVERSE) { safe_addstr(win, value) }
              safe_addstr(win, suffix)
            else
              safe_addstr(win, segment)
            end
          end
        end

        def active_subfield
          subfields.fetch(@selected_subfield, subfields.first)
        end

        def highlighted_segment_index
          subfield_segment_indexes.fetch(active_subfield)
        end

        def highlighted_segment_parts(_idx, segment)
          ["", segment, ""]
        end
      end
    end
  end
end
