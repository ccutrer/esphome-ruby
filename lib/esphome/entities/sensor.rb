# frozen_string_literal: true

module ESPHome
  module Entities
    class Sensor < Entity
      include HasDeviceClass
      include HasState

      attr_reader :unit_of_measurement,
                  :accuracy_decimals,
                  :state_class

      def initialize(_device, list_entities_response)
        super

        @unit_of_measurement = list_entities_response.unit_of_measurement
        @accuracy_decimals = list_entities_response.accuracy_decimals
        @force_update = list_entities_response.force_update
        @state_class = list_entities_response.state_class[12..].downcase.to_sym
      end

      def force_update?
        @force_update
      end

      def formatted_state
        result = if state
                   format("%.#{accuracy_decimals}f", state)
                 else
                   "-"
                 end
        result += " #{unit_of_measurement}" if unit_of_measurement
        result
      end

      private

      def inspection_vars
        super + %i[unit_of_measurement accuracy_decimals force_update? state_class]
      end

      def hideable?(var, val)
        super ||
          (var == :force_update? && !val) ||
          (var == :state_class && val == :none)
      end
    end
  end
end
