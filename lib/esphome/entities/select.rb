# frozen_string_literal: true

module ESPHome
  module Entities
    class Select < Entity
      include HasState

      attr_reader :options

      def initialize(_device, list_entities_response)
        super

        @options = list_entities_response.options.map(&:freeze).freeze
      end

      def command(state)
        device.send(Api::SelectCommandRequest.new(key:, state:))
      end

      private

      def inspection_vars
        super + [:options]
      end
    end
  end
end
