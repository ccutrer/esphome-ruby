# frozen_string_literal: true

require "httpx"

module ESPHome
  class Dashboard
    def initialize(uri)
      @http = HTTPX.plugin(:persistent).with(origin: uri)
    end

    def devices
      @http.get("/devices").tap(&:raise_for_status).json["configured"]
    end

    def config(configuration)
      @http.get("/json-config", params: { configuration: }).tap(&:raise_for_status).json
    end

    def encryption_key(configuration)
      config(configuration).dig("api", "encryption", "key")
    end
  end
end
