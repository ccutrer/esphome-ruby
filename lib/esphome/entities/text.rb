# frozen_string_literal: true

module ESPHome
  module Entities
    class Text < Entity
      include HasState

      attr_reader :length_range, :pattern, :mode

      def initialize(_device, list_entities_response)
        super

        @length_range = Range.new(list_entities_response.min_length, list_entities_response.max_length)
        @pattern = list_entities_response.pattern.empty? ? nil : list_entities_response.pattern
        @mode = list_entities_response.mode[10..].downcase.to_sym
      end

      def command(state)
        device.send(Api::TextCommandRequest.new(key:, state:))
      end

      private

      def inspection_vars
        super + %i[length_range pattern mode]
      end

      def hideable?(var, val)
        super ||
          (var == :length_range && length_range == (0..0)) ||
          (var == :pattern && pattern.nil?) ||
          (var == :mode && val == :text)
      end
    end
  end
end
