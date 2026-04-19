# frozen_string_literal: true

module ESPHome
  module Entities
    class Climate < Entity
      include HasState

      BASE_FAN_MODES = Api::ClimateCommandRequest.descriptor.lookup("fan_mode")
                                                 .subtype
                                                 .map { |value| value.name[12..].downcase.to_sym }
                                                 .freeze
      private_constant :BASE_FAN_MODES
      BASE_PRESETS = Api::ClimateCommandRequest.descriptor.lookup("preset")
                                               .subtype
                                               .map { |value, _number| value.to_s }
                                               .reject { |value| value == "CLIMATE_PRESET_NONE" }
                                               .map { |value| value[15..].downcase.to_sym }
                                               .freeze
      private_constant :BASE_PRESETS

      module Features
        SUPPORTS_CURRENT_TEMPERATURE = 1 << 0
        SUPPORTS_TWO_POINT_TARGET_TEMPERATURE = 1 << 1
        REQUIRES_TWO_POINT_TARGET_TEMPERATURE = 1 << 2
        SUPPORTS_CURRENT_HUMIDITY = 1 << 3
        SUPPORTS_TARGET_HUMIDITY = 1 << 4
        SUPPORTS_ACTION = 1 << 5
      end

      attr_reader :supported_modes,
                  :visual_temperature_range,
                  :visual_target_temperature_step,
                  :supported_fan_modes,
                  :supported_swing_modes,
                  :supported_presets,
                  :visual_humidity_range,
                  :current_temperature,
                  :target_temperature,
                  :target_temperature_low,
                  :target_temperature_high,
                  :action,
                  :fan_mode,
                  :swing_mode,
                  :preset,
                  :current_humidity,
                  :target_humidity

      def initialize(_device, list_entities_response)
        super

        if list_entities_response.feature_flags
          @supports_current_temperature = list_entities_response.feature_flags.anybits?(Features::SUPPORTS_CURRENT_TEMPERATURE)
          @supports_two_point_target_temperature = list_entities_response.feature_flags.anybits?(Features::SUPPORTS_TWO_POINT_TARGET_TEMPERATURE)
          @supports_current_humidity = list_entities_response.feature_flags.anybits?(Features::SUPPORTS_CURRENT_HUMIDITY)
          @supports_target_humidity = list_entities_response.feature_flags.anybits?(Features::SUPPORTS_TARGET_HUMIDITY)
          @supports_action = list_entities_response.feature_flags.anybits?(Features::SUPPORTS_ACTION)
        else
          @supports_current_temperature = list_entities_response.supports_current_temperature
          @supports_two_point_target_temperature = list_entities_response.supports_two_point_target_temperature
          @supports_current_humidity = list_entities_response.supports_current_humidity
          @supports_target_humidity = list_entities_response.supports_target_humidity
          @supports_action = list_entities_response.supports_action
        end
        @supported_modes = list_entities_response.supported_modes.map { |m| m[13..].downcase.to_sym }.freeze
        @visual_temperature_range = Range.new(list_entities_response.visual_min_temperature,
                                              list_entities_response.visual_max_temperature)
        @visual_target_temperature_step = list_entities_response.visual_target_temperature_step
        @supported_fan_modes = list_entities_response.supported_fan_modes.map { |m| m[12..].downcase.to_sym }
        @supported_swing_modes = list_entities_response.supported_swing_modes.map { |m| m[14..].downcase.to_sym }.freeze
        @supported_fan_modes.concat(list_entities_response.supported_custom_fan_modes.map(&:to_sym))
        @supported_fan_modes.freeze
        @supported_presets = list_entities_response.supported_presets.map { |p| p[15..].downcase.to_sym }
        if list_entities_response.legacy_supports_away && !@supported_presets.include?(:away)
          @supported_presets.push(:away)
        end
        @supported_presets.concat(list_entities_response.supported_custom_presets.map(&:to_sym))
        @supported_presets.freeze
        @visual_humidity_range = Range.new(list_entities_response.visual_min_humidity,
                                           list_entities_response.visual_max_humidity)
      end

      def current_temperature?
        @supports_current_temperature
      end

      def two_point_target_temperature?
        @supports_two_point_target_temperature
      end

      def action?
        @supports_action
      end

      def current_humidity?
        @supports_current_humidity
      end

      def target_humidity?
        @supports_target_humidity
      end

      def update(state_response)
        @state = state_response.mode[13..].downcase.to_sym
        @current_temperature = state_response.current_temperature if current_temperature?
        if two_point_target_temperature?
          @target_temperature_low = state_response.target_temperature_low
          @target_temperature_high = state_response.target_temperature_high
        else
          @target_temperature = state_response.target_temperature
        end
        @action = state_response.action[15..].downcase.to_sym if action?
        @fan_mode = if state_response.custom_fan_mode.empty?
                      state_response.fan_mode[12..].downcase.to_sym
                    else
                      state_response.custom_fan_mode.downcase.to_sym
                    end
        @swing_mode = state_response.swing_mode[14..].downcase.to_sym
        @preset = if !state_response.custom_preset.empty?
                    state_response.custom_preset.to_sym
                  elsif state_response.unused_legacy_away
                    :away
                  elsif state_response.preset == :CLIMATE_PRESET_NONE
                    nil
                  else
                    state_response.preset[15..].downcase.to_sym
                  end
        @current_humidity = state_response.current_humidity if current_humidity?
        @target_humidity = state_response.target_humidity if target_humidity?
      end

      def formatted_state
        formatted_segments.join(" ")
      end

      def formatted_segments
        segments = [state.nil? ? "-" : state.to_s]
        segments << "(#{action || "-"})" if action?
        segments << "#{current_temperature || "-"} °C /" if current_temperature?
        if two_point_target_temperature?
          segments << formatted_target_low_segment
          segments << "-"
          segments << formatted_target_high_segment
        else
          segments << formatted_target_segment
        end
        segments << "fan: #{fan_mode || "-"}" unless supported_fan_modes.empty?
        segments << "swing: #{swing_mode || "-"}" unless supported_swing_modes.empty?
        segments << formatted_preset_segment unless supported_presets.empty?
        segments << "#{current_humidity || "-"} %RH" if current_humidity?
        segments << "/" if current_humidity? && target_humidity?
        segments << "#{target_humidity || "-"} %RH" if target_humidity?
        segments
      end

      def formatted_target_segment
        "#{target_temperature || "-"} °C"
      end

      def formatted_target_low_segment
        "#{target_temperature_low || "-"} °C"
      end

      def formatted_target_high_segment
        "#{target_temperature_high || "-"} °C"
      end

      def formatted_fan_segment
        "fan: #{fan_mode || "-"}"
      end

      def formatted_swing_segment
        "swing: #{swing_mode || "-"}"
      end

      def formatted_preset_segment
        preset ? preset.to_s : "<preset>"
      end

      def temperature_decimals
        str = visual_target_temperature_step.to_s
        return 0 unless str.include?(".")

        str.split(".").last.sub(/0+\z/, "").length
      end

      def format_temperature(value)
        return "-" if value.nil?

        format("%.#{temperature_decimals}f °C", value)
      end

      def format_humidity(value)
        return "-" if value.nil?

        format("%.0f %%RH", value)
      end

      def change_mode(mode)
        device.send(Api::ClimateCommandRequest.new(key:,
                                                   has_mode: true,
                                                   mode: :"CLIMATE_MODE_#{mode.to_s.upcase}"))
      end

      def change_fan_mode(mode)
        mode = mode.to_sym
        if BASE_FAN_MODES.include?(mode)
          device.send(Api::ClimateCommandRequest.new(key:,
                                                     has_fan_mode: true,
                                                     fan_mode: :"CLIMATE_FAN_#{mode.to_s.upcase}"))
        else
          device.send(Api::ClimateCommandRequest.new(key:,
                                                     has_custom_fan_mode: true,
                                                     custom_fan_mode: mode.to_s))
        end
      end

      def change_target_temperature(value = nil, low: nil, high: nil)
        command = Api::ClimateCommandRequest.new(key:)
        if low
          command.has_target_temperature_low = true
          command.target_temperature_low = low
        end
        if high
          command.has_target_temperature_high = true
          command.target_temperature_high = high
        end
        if value
          command.has_target_temperature = true
          command.target_temperature = value
        end
        device.send(command)
      end

      def change_swing_mode(mode)
        device.send(Api::ClimateCommandRequest.new(key:,
                                                   has_swing_mode: true,
                                                   swing_mode: :"CLIMATE_SWING_#{mode.to_s.upcase}"))
      end

      def change_target_humidity(value)
        device.send(Api::ClimateCommandRequest.new(key:,
                                                   has_target_humidity: true,
                                                   target_humidity: value))
      end

      def change_preset(value)
        value = value.to_sym
        if BASE_PRESETS.include?(value)
          device.send(Api::ClimateCommandRequest.new(key:,
                                                     has_preset: true,
                                                     preset: :"CLIMATE_PRESET_#{value.to_s.upcase}"))
        else
          device.send(Api::ClimateCommandRequest.new(key:,
                                                     has_custom_preset: true,
                                                     custom_preset: value.to_s))
        end
      end
    end
  end
end
