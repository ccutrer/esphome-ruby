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

      def command(command, code = nil)
        message = Api::LockCommandRequest.new(key:, command: :"LOCK_#{command.to_s.upcase}")
        if code
          message.code = code
          message.has_code = true
        end
        device.send(message)
      end

      def lock(code = nil) = command(:lock, code)
      def unlock(code = nil) = command(:unlock, code)
      def open(code = nil) = command(:open, code)

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
