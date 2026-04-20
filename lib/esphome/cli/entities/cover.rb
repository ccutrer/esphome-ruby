# frozen_string_literal: true

require_relative "form"
require_relative "subfields"

module ESPHome
  module Cli
    module Entities
      class Cover < Subfields
        include FormPrompt

        VERBS = {
          open: "Opening",
          close: "Closing",
          stop: "Stopping"
        }.freeze
        private_constant :VERBS

        private

        def subfields
          items = []
          items << :position if position?
          items << :tilt if tilt?
          items << :current_operation
          items
        end

        def subfield_segment_indexes
          segment_index = 0
          indexes = {}
          indexes[:position] = segment_index if position?
          if tilt?
            segment_index += 2
            indexes[:tilt] = segment_index
          end
          segment_index += 1
          indexes[:current_operation] = segment_index
          indexes
        end

        def highlighted_segment_parts(idx, segment)
          return ["", segment, ""] unless idx == highlighted_segment_index && active_subfield == :current_operation

          value = (current_operation || "-").to_s
          ["(", value, ")"]
        end

        def activate_position
          value = prompt_percentage("Position", position)
          return if value.nil?

          cli.info("Setting #{object_id_} position to #{percentage_label(value)}")
          command(position: value)
        end

        def activate_tilt
          value = prompt_percentage("Tilt", tilt)
          return if value.nil?

          cli.info("Setting #{object_id_} tilt to #{percentage_label(value)}")
          command(tilt: value)
        end

        def activate_current_operation
          choice = prompt_menu("Operation", operation_options, current_operation_option)
          return unless choice

          choice = choice.to_sym
          cli.info("#{VERBS[choice]} #{object_id_}")
          __send__(choice)
        end

        def prompt_percentage(title, value)
          initial_value = format("%d", (value * 100).round) if value
          choice = prompt_form(title,
                               initial_value:,
                               suffix: "%",
                               field_width: 3)
          return unless choice

          normalize_percentage(choice)
        end

        def percentage_label(value)
          "#{(value * 100).round}%"
        end

        def normalize_percentage(value)
          value = Float(value).round.clamp(0, 100)
          value / 100.0
        rescue ArgumentError
          cli.error("Invalid percentage: #{value}")
          nil
        end

        def operation_options
          options = %w[open close]
          options << "stop" if stop?
          options
        end

        def current_operation_option
          case current_operation
          when :opening
            "open"
          when :closing
            "close"
          when :idle
            "stop" if stop?
          end
        end
      end
    end
  end
end
