# frozen_string_literal: true

RSpec.describe ESPHome::Entities::TextSensor, yaml: <<~YAML do
  text_sensor:
    - platform: template
      id: test_text_sensor
      name: Test Text Sensor

  button:
    - platform: template
      name: Trigger Text Sensor Update
      on_press:
        - text_sensor.template.publish:
            id: test_text_sensor
            state: ready
YAML

  include_context "with Host Device"

  it "receives text sensor state updates" do
    text_sensor = entity_named("Test Text Sensor")
    expect(text_sensor).to be_a(described_class)

    expect(text_sensor.state).to be_nil

    entity_named("Trigger Text Sensor Update").press
    host_device.wait_until do
      expect(text_sensor.state).to eql "ready"
    end
  end
end
