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

    def config_hash(configuration)
      @http.get("/config-hash", params: { configuration: })
           .tap(&:raise_for_status)
           .read
           .strip
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

    def update(configuration, port: :ota, force: false, &)
      unless force
        require "esphome/device"

        begin
          config = self.config(configuration)
          current_hash = config_hash(configuration)
          running_hash = nil
          address = config.dig("wifi", "use_address") || config.dig("ethernet", "use_address")
          encryption_key = encryption_key(configuration)
          puts "Connecting to #{config.dig("esphome", "name")} to check config hash"
          device = Device.new(address, encryption_key)
          device.connect
          text_sensors = device.entities.values.grep(Entities::TextSensor)
          if text_sensors.empty?
            device.disconnect
          else
            device.on_message do |entity|
              next unless entity.is_a?(Entities::TextSensor)

              text_sensors.delete(entity)
              if entity.state &&
                 (match = entity.state.match(/^\d{4}\.\d+\.\d+ \(config hash (0x[0-9a-fA-F]{8})\)/))
                running_hash = match[1]
                device.disconnect
                next
              end
              device.disconnect if text_sensors.empty?
            end
            device.stream_states
            device.loop
          end

          if running_hash.nil?
            warn("Could not find config hash from device. Do you have the version text sensor configured?")
          end

          return :skipped if running_hash && running_hash == current_hash
        rescue HTTPX::Error
          warn("Could not fetch configuration for #{configuration}")
          return false
        rescue IOError, SocketError, SystemCallError, Timeout::Error
          warn("Could not connect to #{address}")
          return false
        end
      end

      compile(configuration, &) && upload(configuration, port:, &)
    end

    def update_all(devices = self.devices, force: false, &)
      devices.to_h do |device|
        [device, update(device["configuration"], force:, &)]
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
