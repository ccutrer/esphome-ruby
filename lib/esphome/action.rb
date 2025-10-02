# frozen_string_literal: true

module ESPHome
  class Action
    class << self
      def from_protobuf(message)
        data = message.data.to_h { |kv| [kv.key, kv.value] }
        data_template = message.data_template.to_h { |kv| [kv.key, kv.value] }
        variables = message.variables.to_h { |kv| [kv.key, kv.value] }
        if message.is_event
          if message.service == TagScanned::SERVICE &&
             data.keys == ["tag_id"] &&
             data_template.empty? &&
             variables.empty?
            TagScanned.new(data["tag_id"])
          else
            Event.new(message.service, data, data_template, variables)
          end
        else
          Action.new(message.service, data, data_template, variables)
        end
      end
    end

    attr_reader :service, :data, :data_template, :variables

    def initialize(service, data = {}, data_template = {}, variables = {})
      @service = service
      @data = data
      @data_template = data_template
      @variables = variables
    end

    def inspect
      "#<#{self.class.name} service=#{service} " \
        "data=#{data.inspect} " \
        "data_template=#{data_template.inspect} " \
        "variables=#{variables.inspect}>"
    end
  end

  class Event < Action; end

  class TagScanned < Event
    SERVICE = "esphome.tag_scanned"

    def initialize(tag_id)
      super(SERVICE, { "tag_id" => tag_id })
    end

    def inspect
      "#<#{self.class.name} tag_id=#{data["tag_id"].inspect}>"
    end
  end
end
