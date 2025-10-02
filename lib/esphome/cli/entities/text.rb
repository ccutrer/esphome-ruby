# frozen_string_literal: true

require_relative "form"

module ESPHome
  module Cli
    module Entities
      class Text < Form
        def command(value)
          cli.info("Setting #{object_id_} to #{value}")
          super
        end
      end
    end
  end
end
