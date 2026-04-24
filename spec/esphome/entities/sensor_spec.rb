# frozen_string_literal: true

RSpec.describe ESPHome::Entities::Sensor, yaml: <<~YAML do
  sensor:
    - platform: template
      id: test_sensor
      name: Test Sensor
      accuracy_decimals: 1
      unit_of_measurement: C

  button:
    - platform: template
      name: Trigger Sensor Update
      on_press:
        - sensor.template.publish:
            id: test_sensor
            state: 12.5
YAML

  include_context "with Host Device"

  it "receives sensor state updates" do
    sensor = entity_named("Test Sensor")
    expect(sensor).to be_a(described_class)
    expect(sensor.state).to be_nil

    entity_named("Trigger Sensor Update").press
    host_device.wait_until do
      expect(sensor.state).to be_within(0.001).of(12.5)
    end

    expect(sensor.formatted_state).to eql "12.5 C"
  end
end
