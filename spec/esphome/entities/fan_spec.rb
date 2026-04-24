# frozen_string_literal: true

RSpec.describe ESPHome::Entities::Fan, yaml: <<~YAML do
  fan:
    - platform: template
      id: test_fan
      name: Test Fan
      has_direction: true
      has_oscillating: true
      speed_count: 5

  button:
    - platform: template
      name: Trigger Fan State Update
      on_press:
        - fan.turn_on:
            id: test_fan
            speed: 4
            oscillating: true
            direction: REVERSE
YAML

  include_context "with Host Device"

  it "receives fan state updates" do
    fan = entity_named("Test Fan")
    expect(fan).to be_a(described_class)

    entity_named("Trigger Fan State Update").press
    host_device.wait_until do
      expect(fan.state).to be true
      expect(fan.speed).to be 4
      expect(fan).to be_oscillating
      expect(fan.direction).to be :reverse
    end
  end
end
