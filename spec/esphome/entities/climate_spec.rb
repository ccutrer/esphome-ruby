# frozen_string_literal: true

RSpec.describe ESPHome::Entities::Climate, yaml: <<~YAML do
  sensor:
    - platform: template
      id: current_temperature
      name: Current Temperature

  climate:
    - platform: bang_bang
      id: test_climate
      name: Test Climate
      sensor: current_temperature
      default_target_temperature_low: 20
      default_target_temperature_high: 23
      idle_action:
        - logger.log: "idle"
      cool_action:
        - logger.log: "cool"
      heat_action:
        - logger.log: "heat"

  button:
    - platform: template
      name: Trigger Climate Temperature Update
      on_press:
        - sensor.template.publish:
            id: current_temperature
            state: 21.5
YAML

  include_context "with Host Device"

  it "sends climate commands and receives the updated state" do
    climate = entity_named("Test Climate")
    expect(climate).to be_a(described_class)

    expect(climate.current_temperature).to be_nan

    entity_named("Trigger Climate Temperature Update").press
    host_device.wait_until do
      expect(climate.current_temperature).to be_within(0.001).of(21.5)
    end

    climate.change_mode(:heat)
    host_device.wait_until do
      expect(climate.state).to be :heat
    end

    climate.change_mode(:cool)
    host_device.wait_until do
      expect(climate.state).to be :cool
    end
  end
end
