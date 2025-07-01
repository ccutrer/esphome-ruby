# frozen_string_literal: true

module ESPHome
  module Entities
    class BinarySensor < Entity
      include HasState

      def initialize(_device, list_entities_response)
        super
        @status = list_entities_response.is_status_binary_sensor
      end

      def status?
        @status
      end

      private

      def inspection_vars
        super + [:status?]
      end

      def hideable?(var, val)
        super || (var == :status? && !val)
      end
    end
  end
end
