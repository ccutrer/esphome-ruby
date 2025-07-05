# frozen_string_literal: true

module ESPHome
  module Entities
    class Number < Entity
      include HasDeviceClass
      include HasState

      attr_reader :range, :step, :unit_of_measurement, :mode

      def initialize(_device, list_entities_response)
        super

        @range = Range.new(list_entities_response.min_value, list_entities_response.max_value)
        @max_value = list_entities_response.max_value
        @step = list_entities_response.step
        @unit_of_measurement = list_entities_response.unit_of_measurement
        @mode = list_entities_response.mode[12..].downcase.to_sym
      end

      def accuracy_decimals
        str = step.to_s
        return 0 unless str.include?(".")

        decimals = str.split(".").last
        return 0 if decimals == "0"

        decimals.size
      end

      def formatted_state(state = self.state)
        result = if state
                   format("%.#{accuracy_decimals}f", state)
                 else
                   "-"
                 end
        result += " #{unit_of_measurement}" if unit_of_measurement
        result
      end

      def set(state)
        device.send(Api::NumberCommandRequest.new(key:, state:))
      end

      private

      def inspection_vars
        super + %i[range step unit_of_measurement mode]
      end

      def hideable?(var, val)
        super || (var == :mode && val == :auto)
      end
    end
  end
end
