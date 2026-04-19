# frozen_string_literal: true

require_relative "form"
require_relative "menu"

module ESPHome
  module Cli
    module Entities
      class Climate < Entity
        include MenuPrompt
        include FormPrompt

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
          __send__(:"activate_#{subfields.fetch(@selected_subfield, :mode)}")
        end

        private

        def print_state(win, active:)
          formatted_segments.each_with_index do |segment, idx|
            safe_addstr(win, " ") unless idx.zero?
            if active && idx == highlighted_segment_index
              prefix, value = highlighted_segment_parts(idx, segment)
              safe_addstr(win, prefix)
              win.attron(Curses::A_REVERSE) { safe_addstr(win, value) }
            else
              safe_addstr(win, segment)
            end
          end
        end

        def subfields
          items = [:mode]
          if two_point_target_temperature?
            items << :target_temperature_low
            items << :target_temperature_high
          else
            items << :target_temperature
          end
          items << :fan_mode unless supported_fan_modes.empty?
          items << :swing_mode unless supported_swing_modes.empty?
          items << :preset unless supported_presets.empty?
          items << :target_humidity if target_humidity?
          items
        end

        def highlighted_segment_index
          selected_subfield = subfields.fetch(@selected_subfield, :mode)
          segment_index = 0

          return segment_index if selected_subfield == :mode

          segment_index += 1 if action?
          segment_index += 1 if current_temperature?

          segment_index += 1
          return segment_index if selected_subfield == :target_temperature
          return segment_index if two_point_target_temperature? && selected_subfield == :target_temperature_low

          if two_point_target_temperature?
            segment_index += 1 # literal "-"
            segment_index += 1
            return segment_index if selected_subfield == :target_temperature_high
          end

          unless supported_fan_modes.empty?
            segment_index += 1
            return segment_index if selected_subfield == :fan_mode
          end

          unless supported_swing_modes.empty?
            segment_index += 1
            return segment_index if selected_subfield == :swing_mode
          end

          unless supported_presets.empty?
            segment_index += 1
            return segment_index if selected_subfield == :preset
          end

          segment_index += 1 if current_humidity?
          segment_index += 1 if current_humidity? && target_humidity?

          return unless target_humidity?

          segment_index += 1
          segment_index if selected_subfield == :target_humidity
        end

        def highlighted_segment_parts(idx, segment)
          active_subfield = subfields.fetch(@selected_subfield, :mode)

          if idx == highlighted_segment_index && active_subfield == :fan_mode
            value = (fan_mode || "-").to_s
            [formatted_fan_segment.delete_suffix(value), value]
          elsif idx == highlighted_segment_index && active_subfield == :swing_mode
            value = (swing_mode || "-").to_s
            [formatted_swing_segment.delete_suffix(value), value]
          else
            ["", segment]
          end
        end

        def activate_mode
          choice = prompt_select("Mode", supported_modes.map(&:to_s), state&.to_s)
          return unless choice

          cli.info("Setting #{object_id_} mode to #{choice}")
          change_mode(choice)
        end

        def activate_fan_mode
          choice = prompt_select("Fan Mode", supported_fan_modes.map(&:to_s), fan_mode&.to_s)
          return unless choice

          cli.info("Setting #{object_id_} fan mode to #{choice}")
          change_fan_mode(choice)
        end

        def activate_swing_mode
          choice = prompt_select("Swing Mode", supported_swing_modes.map(&:to_s), swing_mode&.to_s)
          return unless choice

          cli.info("Setting #{object_id_} swing mode to #{choice}")
          change_swing_mode(choice)
        end

        def activate_preset
          options = supported_presets.map(&:to_s)
          choice = prompt_select("Preset", options, preset&.to_s)
          return unless choice

          cli.info("Setting #{object_id_} preset to #{choice}")
          change_preset(choice)
        end

        def activate_target_temperature
          value = prompt_number("Target Temperature",
                                initial_value: target_temperature,
                                suffix: "°C")
          return unless value

          cli.info("Setting #{object_id_} target to #{format_temperature(value)}")
          change_target_temperature(value)
        end

        def activate_target_temperature_low
          value = prompt_number("Target Low",
                                initial_value: target_temperature_low,
                                suffix: "°C")
          return unless value

          cli.info("Setting #{object_id_} target low to #{format_temperature(value)}")
          change_target_temperature(low: value)
        end

        def activate_target_temperature_high
          value = prompt_number("Target High",
                                initial_value: target_temperature_high,
                                suffix: "°C")
          return unless value

          cli.info("Setting #{object_id_} target high to #{format_temperature(value)}")
          change_target_temperature(high: value)
        end

        def activate_target_humidity
          value = prompt_number("Target Humidity",
                                initial_value: target_humidity,
                                suffix: "%RH",
                                decimals: 0,
                                range: visual_humidity_range)
          return unless value

          cli.info("Setting #{object_id_} target humidity to #{format_humidity(value)}")
          change_target_humidity(value)
        end

        def prompt_select(title, options, current)
          prompt_menu(title, options, current)
        end

        def prompt_number(title, initial_value:, suffix:, decimals: nil, range: nil)
          decimals ||= temperature_decimals
          initial_value = format("%.#{decimals}f", initial_value) if initial_value
          value = prompt_form(title,
                              initial_value:,
                              suffix:,
                              field_width: number_field_width(range, decimals))
          return unless value

          normalize_number(value, range:, decimals:)
        end

        def normalize_number(value, range:, decimals:)
          number = Float(value)
          number = number.round(decimals)
          return number unless range

          number.clamp(range)
        rescue ArgumentError
          cli.error("Invalid number: #{value}")
          nil
        end

        def number_field_width(range, decimals)
          range ||= visual_temperature_range
          [
            number_display_width(range.begin, decimals),
            number_display_width(range.end, decimals),
            6
          ].max
        end

        def number_display_width(number, decimals)
          format("%.#{decimals}f", number).length
        end
      end
    end
  end
end
