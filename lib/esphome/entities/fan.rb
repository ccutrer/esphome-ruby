# frozen_string_literal: true

module ESPHome
  module Entities
    class Fan < Entity
      include HasState

      attr_reader :speed_count,
                  :preset_modes,
                  :speed,
                  :direction,
                  :preset_mode

      def initialize(_device, list_entities_response)
        super

        @supports_oscillation = list_entities_response.supports_oscillation
        @supports_speed = list_entities_response.supports_speed
        @speed_count = list_entities_response.supported_speed_count if speed?
        @speed_count = 3 if speed_count.zero? && speed?
        @preset_modes = list_entities_response.preset_modes.map(&:freeze).freeze

        @oscillating = @speed = @direction = @preset_mode = nil
      end

      def oscillation?
        @supports_oscillation
      end

      def speed?
        @supports_speed
      end

      def oscillating?
        @oscillating
      end

      def formatted_state
        result = case state
                 when nil then "-"
                 when true then "on"
                 else "off"
                 end
        if speed?
          result +=
            if speed_count == 100
              " #{speed || "-"}%"
            else
              " #{speed || "-"}/#{speed_count}"
            end
        end
        result += " oscillating" if oscillating?
        result += " reversed" if direction == :reverse
        result += " (#{preset_mode})" if preset_mode
        result
      end

      def update(state_response)
        @state = state_response.state
        @oscillating = state_response.oscillating
        @speed = state_response.speed_level
        if speed? && speed.nil?
          @speed = { FAN_SPEED_LOW: 1,
                     FAN_SPEED_MEDIUM: 2,
                     FAN_SPEED_HIGH: 3 }[state_response.speed]
        end
        @direction = state_response.direction[14..].downcase.to_sym
        @preset_mode = state_response.preset_mode.empty? ? nil : state_response.preset_mode
      end

      private

      def inspection_vars
        super + %i[oscillation? speed_count preset_modes speed oscillating? direction preset_mode]
      end

      def hideable?(var, val)
        super ||
          (var == :oscillation && !oscillation?) ||
          (var == :speed_count && !speed?) ||
          (var == :preset_modes && preset_modes.empty?) ||
          (var == :speed && !speed?) ||
          (var == :oscillating && !oscillating?) ||
          (var == :direction && direction == :forward) ||
          (var == :preset_mode && preset_mode.nil?)
      end
    end
  end
end
