# frozen_string_literal: true

require "httpx"

module ESPHome
  class Dashboard
    def initialize(uri)
      @http = HTTPX.plugin(:persistent).with(origin: uri)
      @websocket = nil
    end

    def devices
      @http.get("/devices").tap(&:raise_for_status).json["configured"]
    end

    def config(configuration)
      @http.get("/json-config", params: { configuration: })
           .tap(&:raise_for_status)
           .json(allow_nan: true)
    end

    def encryption_key(configuration)
      config(configuration).dig("api", "encryption", "key")
    end

    def compile(configuration, &)
      websocket_command("/compile", { type: "spawn", configuration: }, &)
    end

    def upload(configuration, port: :ota, &)
      port = "OTA" if port == :ota
      websocket_command("/upload", { type: "spawn", configuration:, port: }, &)
    end

    def update(configuration, port: :ota, &)
      compile(configuration, &) && upload(configuration, port:, &)
    end

    def update_all(devices = self.devices, &)
      devices.to_h do |device|
        [device, update(device["configuration"], &)]
      end
    end

    private

    def websocket_command(path, json_message) # rubocop:disable Naming/PredicateMethod
      driver = websocket.get(path).tap(&:raise_for_status).driver

      driver.on(:open) do
        driver.text(json_message.to_json)
      end

      exit_code = nil
      driver.on(:message) do |msg|
        data = JSON.parse(msg.data)
        case data["event"]
        when "line"
          yield data["data"].gsub("\\033", "\033") if block_given?
        when "exit"
          driver.close
          exit_code = data["code"]
        end
      end

      driver.start
      driver.run
      exit_code.zero?
    end

    def websocket
      @websocket ||= @http.plugin(:websocket)
    end
  end
end
