# frozen_string_literal: true

module ESPHome
  module Entities
    class Cover < Entity
      include HasDeviceClass
      include HasAssumedState
      include HasState

      attr_reader :position, :tilt, :current_operation

      def initialize(_device, list_entities_response)
        super

        @supports_position = list_entities_response.supports_position
        @supports_tilt = list_entities_response.supports_tilt
        @position = @tilt = @current_operation = nil
      end

      def position?
        @supports_position
      end

      def tilt?
        @supports_tilt
      end

      def formatted_state
        result = if position?
                   "#{position ? position * 100 : "-"}%"
                 else
                   super
                 end
        result += " - #{tilt || "-"}%" if tilt?
        result += " (#{current_operation})" if current_operation
        result
      end

      def update(state_response)
        @state = state_response.legacy_state[19..].downcase.to_sym
        @position = state_response.position if position?
        @tilt = state_response.tilt if tilt?

        @current_operation = if state_response.current_operation == :COVER_OPERATION_IDLE
                               :idle
                             else
                               state_response.current_operation[19..].downcase.to_sym
                             end
      end

      def command(position: nil, tilt: nil)
        command = Api::CoverCommandRequest.new(key:)
        if position
          command.has_position = true
          command.position = position
        end
        if tilt
          command.has_tilt = true
          command.tilt = tilt
        end
        device.send(command)
      end

      def open
        device.send(Api::CoverCommandRequest.new(key:,
                                                 has_legacy_command: true,
                                                 legacy_command: :LEGACY_COVER_COMMAND_OPEN))
      end

      def close
        device.send(Api::CoverCommandRequest.new(key:,
                                                 has_legacy_command: true,
                                                 legacy_command: :LEGACY_COVER_COMMAND_CLOSE))
      end

      def stop
        device.send(Api::CoverCommandRequest.new(key:, stop: true))
      end

      private

      def inspection_vars
        super + %i[position tilt current_operation]
      end

      def hideable?(var, val)
        super ||
          (var == :position && !position?) ||
          (var == :tilt && !tilt?)
      end
    end
  end
end
