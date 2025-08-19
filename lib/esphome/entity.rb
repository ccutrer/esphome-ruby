# frozen_string_literal: true

module ESPHome
  class Entity
    module HasState
      def self.included(klass)
        super

        klass.attr_reader :state
      end

      def initialize(...)
        super
        @state = nil
      end

      def update(state_response)
        @state = state_response.missing_state ? nil : state_response.state
      end

      def formatted_state
        state.nil? ? "-" : state.to_s
      end

      private

      def inspection_vars
        super + [:state]
      end
    end

    module HasAssumedState
      def self.included(klass)
        super

        klass.attr_reader :assumed_state
      end

      def initialize(_device, list_entities_response)
        super

        @assumed_state = list_entities_response.assumed_state
      end

      def assumed_state?
        @assumed_state
      end

      private

      def inspection_vars
        super + [:assumed_state?]
      end

      def hideable?(var, val)
        super || (var == :assumed_state? && !val)
      end
    end

    module HasDeviceClass
      def self.included(klass)
        super

        klass.attr_reader :device_class
      end

      def initialize(_device, list_entities_response)
        super

        @device_class = list_entities_response.device_class.empty? ? nil : list_entities_response.device_class
      end

      private

      def inspection_vars
        super + [:device_class]
      end

      def hideable?(var, val)
        super || (var == :device_class && val.nil?)
      end
    end

    attr_reader :device,
                :object_id_,
                :key,
                :name,
                :icon,
                :disabled_by_default,
                :entity_category

    def initialize(device, list_entities_response)
      @device = device
      @object_id_ = list_entities_response["object_id"]
      @key = list_entities_response.key
      @name = list_entities_response.name
      @icon = list_entities_response.icon.empty? ? nil : list_entities_response.icon
      @disabled_by_default = list_entities_response.disabled_by_default
      @entity_category = list_entities_response.entity_category[16..].downcase.to_sym
    end

    def inspect
      vars = inspection_vars.filter_map do |var|
        val = __send__(var)
        next if hideable?(var, val)

        "#{var}=#{val.inspect}"
      end
      "#<#{self.class.name} #{vars.join(", ")}>"
    end

    private

    def inspection_vars
      %i[object_id_ key name icon disabled_by_default entity_category]
    end

    def hideable?(var, val)
      (var == :disabled_by_default && !val) ||
        (var == :icon && val.nil?) ||
        (var == :entity_category && val == :none)
    end
  end
end

require_relative "entities/binary_sensor"
require_relative "entities/button"
require_relative "entities/climate"
require_relative "entities/cover"
require_relative "entities/date"
require_relative "entities/date_time"
require_relative "entities/fan"
require_relative "entities/light"
require_relative "entities/lock"
require_relative "entities/number"
require_relative "entities/select"
require_relative "entities/sensor"
require_relative "entities/switch"
require_relative "entities/text"
require_relative "entities/text_sensor"
require_relative "entities/time"
