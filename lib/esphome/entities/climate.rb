# frozen_string_literal: true

module ESPHome
  module Entities
    class Climate < Entity
      include HasState

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

        @supports_current_temperature = list_entities_response.supports_current_temperature
        @supports_two_point_target_temperature = list_entities_response.supports_two_point_target_temperature
        @supported_modes = list_entities_response.supported_modes.map { |m| m[13..].downcase.to_sym }.freeze
        @visual_temperature_range = Range.new(list_entities_response.visual_min_temperature,
                                              list_entities_response.visual_max_temperature)
        @visual_target_temperature_step = list_entities_response.visual_target_temperature_step
        @supports_action = list_entities_response.supports_action
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
        @supports_current_humidity = list_entities_response.supports_current_humidity
        @supports_target_humidity = list_entities_response.supports_target_humidity
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
        result = super
        result += " (#{action || "-"})" if action?
        result += " #{current_temperature || "-"} °C /" if current_temperature?
        result += if two_point_target_temperature?
                    " #{target_temperature_low || "-"} °C - #{target_temperature_high || "-"} °C"
                  else
                    " #{target_temperature || "-"} °C"
                  end
        result += " fan: #{fan_mode || "-"}" unless supported_fan_modes.empty?
        result += " swing: #{swing_mode || "-"}" unless supported_swing_modes.empty?
        result += " #{preset}" if preset
        result += " #{current_humidity || "-"} %RH" if current_humidity?
        result += "/" if current_humidity? && target_humidity?
        result += " #{target_humidity || "-"} %RH" if target_humidity?

        result
      end
    end
  end
end
