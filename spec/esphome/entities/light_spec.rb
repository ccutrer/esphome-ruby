# frozen_string_literal: true

RSpec.describe ESPHome::Entities::Light, yaml: <<~YAML do
  output:
    - platform: template
      id: test_light_output
      type: float
      write_action:
        - logger.log:
            level: DEBUG
            format: "brightness %.2f"
            args: ["state"]

  light:
    - platform: monochromatic
      id: test_light
      name: Test Light
      output: test_light_output

  button:
    - platform: template
      name: Trigger Light State Update
      on_press:
        - light.turn_on:
            id: test_light
            brightness: 75%
YAML

  include_context "with Host Device"

  it "receives light state updates" do
    light = entity_named("Test Light")
    expect(light).to be_a(described_class)

    entity_named("Trigger Light State Update").press
    host_device.wait_until do
      expect(light.state).to be true
      expect(light.brightness).to be_within(0.001).of(0.75)
    end
  end
end
