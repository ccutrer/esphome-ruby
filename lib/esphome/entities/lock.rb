# frozen_string_literal: true

module ESPHome
  module Entities
    class Lock < Entity
      include HasAssumedState
      include HasState

      def initialize(_device, list_entities_response)
        super
        @supports_open = list_entities_response.supports_open
        @requires_code = list_entities_response.requires_code
      end

      def supports_open?
        @supports_open
      end

      def requires_code?
        @requires_code
      end

      def update(state_response)
        @state = (state_response.state == :LOCK_STATE_NONE) ? nil : state_response.state[11..].downcase.to_sym
      end

      private

      def inspection_vars
        super + %i[supports_open? requires_code?]
      end

      def hideable?(var, val)
        super ||
          (var == :supports_open && val) ||
          (var == :requires_code && val)
      end
    end
  end
end
