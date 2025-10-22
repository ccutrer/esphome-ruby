# frozen_string_literal: true

require "forwardable"
require "websocket/driver"
require "websocket/driver/httpx"

module HTTPX
  module Plugins
    module Websocket
      class << self
        def load_dependencies(klass)
          klass.plugin(:upgrade)
        end

        def call(connection, request, response)
          return unless (driver = request.driver)

          return unless driver.send(:validate_handshake, response.headers)

          connection.hijack_io
          response.instance_variable_set(:@driver, driver)
          driver.instance_variable_set(:@initial_response, response.body.to_s)
        end

        def extra_options(options)
          options.merge(max_concurrent_requests: 1,
                        upgrade_handlers: options.upgrade_handlers.merge("websocket" => self))
        end
      end

      module ConnectionMethods
        def send(request)
          request.init_websocket(self) unless request.driver || @upgrade_protocol

          super
        end
      end

      module RequestMethods
        attr_reader :driver

        def init_websocket(connection)
          if connection.state == :open
            socket = connection.to_io
            @driver = WebSocket::Driver::HTTPX.new(socket, @headers, { masking: true })
          else
            connection.once(:open) do
              socket = connection.to_io
              @driver = WebSocket::Driver::HTTPX.new(socket, @headers, { masking: true })
            end
          end
        end
      end

      module ResponseMethods
        attr_reader :driver
      end
    end

    register_plugin(:websocket, Websocket)
  end
end
