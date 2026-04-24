# frozen_string_literal: true

RSpec.describe ESPHome::Entities::Cover, yaml: <<~YAML do
  cover:
    - platform: template
      id: test_cover
      name: Test Cover
      optimistic: true
      assumed_state: true
      has_position: true
      position_action:
        - cover.template.publish:
            id: test_cover
            position: !lambda return pos;
            current_operation: IDLE
      tilt_action:
        - cover.template.publish:
            id: test_cover
            tilt: !lambda return tilt;

  button:
    - platform: template
      name: Trigger Cover State Update
      on_press:
        - cover.template.publish:
            id: test_cover
            position: 0.1
            tilt: 0.8
            current_operation: IDLE
YAML

  include_context "with Host Device"

  it "sends cover commands and receives the updated state" do
    cover = entity_named("Test Cover")
    expect(cover).to be_a(described_class)

    entity_named("Trigger Cover State Update").press
    host_device.wait_until do
      expect(cover.position).to be_within(0.001).of(0.1)
      expect(cover.tilt).to be_within(0.001).of(0.8)
    end

    cover.command(position: 0.4, tilt: 0.2)
    host_device.wait_until(timeout: 6) do
      expect(cover.position).to be_within(0.001).of(0.4)
      expect(cover.tilt).to be_within(0.001).of(0.2)
      expect(cover.current_operation).to be :idle
    end
  end
end
