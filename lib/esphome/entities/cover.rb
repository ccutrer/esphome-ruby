# frozen_string_literal: true

module ESPHome
  module Entities
    class Cover < Entity
      include HasDeviceClass
      include HasAssumedState

      attr_reader :position, :tilt, :current_operation

      def initialize(_device, list_entities_response)
        super

        @supports_position = list_entities_response.supports_position
        @supports_stop = list_entities_response.supports_stop
        @supports_tilt = list_entities_response.supports_tilt
        @position = @tilt = @current_operation = nil
      end

      def position?
        @supports_position
      end

      def tilt?
        @supports_tilt
      end

      def stop?
        @supports_stop
      end

      def formatted_state
        formatted_segments.join(" ")
      end

      def formatted_segments
        segments = [formatted_position_segment]
        if tilt?
          segments << "-"
          segments << formatted_tilt_segment
        end
        segments << formatted_operation_segment
      end

      def formatted_position_segment
        if position?
          formatted_percentage_segment(position)
        elsif position == 1.0 # rubocop:disable Lint/FloatComparison
          "OPEN"
        elsif position == 0.0
          "CLOSED"
        else
          "-"
        end
      end

      def formatted_tilt_segment
        formatted_percentage_segment(tilt)
      end

      def formatted_operation_segment
        "(#{current_operation || "-"})"
      end

      def update(state_response)
        @position = state_response.position if state_response.position
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
                                                 legacy_command: :LEGACY_COVER_COMMAND_OPEN,
                                                 has_position: true,
                                                 position: 1.0))
      end

      def close
        device.send(Api::CoverCommandRequest.new(key:,
                                                 has_legacy_command: true,
                                                 legacy_command: :LEGACY_COVER_COMMAND_CLOSE,
                                                 has_position: true,
                                                 position: 0.0))
      end

      def stop
        device.send(Api::CoverCommandRequest.new(key:,
                                                 has_legacy_command: true,
                                                 legacy_command: :LEGACY_COVER_COMMAND_STOP,
                                                 stop: true))
      end

      private

      def formatted_percentage_segment(value)
        "#{value.nil? ? "-" : (value * 100).round}%"
      end

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
