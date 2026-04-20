# frozen_string_literal: true

require_relative "form"
require_relative "subfields"

module ESPHome
  module Cli
    module Entities
      class Climate < Subfields
        include FormPrompt

        private

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

        def subfield_segment_indexes
          segment_index = 0
          indexes = { mode: segment_index }

          segment_index += 1 if action?
          segment_index += 1 if current_temperature?

          segment_index += 1
          if two_point_target_temperature?
            indexes[:target_temperature_low] = segment_index
          else
            indexes[:target_temperature] = segment_index
          end
          if two_point_target_temperature?
            segment_index += 1 # literal "-"
            segment_index += 1
            indexes[:target_temperature_high] = segment_index
          end

          unless supported_fan_modes.empty?
            segment_index += 1
            indexes[:fan_mode] = segment_index
          end

          unless supported_swing_modes.empty?
            segment_index += 1
            indexes[:swing_mode] = segment_index
          end

          unless supported_presets.empty?
            segment_index += 1
            indexes[:preset] = segment_index
          end

          segment_index += 1 if current_humidity?
          segment_index += 1 if current_humidity? && target_humidity?
          indexes[:target_humidity] = segment_index + 1 if target_humidity?
          indexes
        end

        def highlighted_segment_parts(idx, segment)
          selected_subfield = active_subfield

          if idx == highlighted_segment_index && selected_subfield == :fan_mode
            value = (fan_mode || "-").to_s
            [formatted_fan_segment.delete_suffix(value), value, ""]
          elsif idx == highlighted_segment_index && selected_subfield == :swing_mode
            value = (swing_mode || "-").to_s
            [formatted_swing_segment.delete_suffix(value), value, ""]
          else
            ["", segment, ""]
          end
        end

        def activate_mode
          choice = prompt_menu("Mode", supported_modes.map(&:to_s), state&.to_s)
          return unless choice

          cli.info("Setting #{object_id_} mode to #{choice}")
          change_mode(choice)
        end

        def activate_fan_mode
          choice = prompt_menu("Fan Mode", supported_fan_modes.map(&:to_s), fan_mode&.to_s)
          return unless choice

          cli.info("Setting #{object_id_} fan mode to #{choice}")
          change_fan_mode(choice)
        end

        def activate_swing_mode
          choice = prompt_menu("Swing Mode", supported_swing_modes.map(&:to_s), swing_mode&.to_s)
          return unless choice

          cli.info("Setting #{object_id_} swing mode to #{choice}")
          change_swing_mode(choice)
        end

        def activate_preset
          options = supported_presets.map(&:to_s)
          choice = prompt_menu("Preset", options, preset&.to_s)
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
