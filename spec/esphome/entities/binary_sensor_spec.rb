# frozen_string_literal: true

RSpec.describe ESPHome::Entities::BinarySensor, yaml: <<~YAML do
  binary_sensor:
    - platform: template
      id: test_binary_sensor
      name: Test Binary Sensor
      device_class: motion

  button:
    - platform: template
      name: Trigger Binary Sensor Update
      on_press:
        - binary_sensor.template.publish:
            id: test_binary_sensor
            state: true
YAML

  include_context "with Host Device"

  it "receives binary sensor state updates" do
    binary_sensor = entity_named("Test Binary Sensor")
    expect(binary_sensor).to be_a(described_class)

    expect(binary_sensor.state).to be_nil

    entity_named("Trigger Binary Sensor Update").press
    host_device.wait_until do
      expect(binary_sensor.state).to be(true)
    end

    expect(binary_sensor.formatted_state).to eql "detected"
  end
end
