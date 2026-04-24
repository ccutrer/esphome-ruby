# frozen_string_literal: true

RSpec.describe ESPHome::Entities::Switch, yaml: <<~YAML do
  switch:
    - platform: template
      id: test_switch
      name: Test Switch
      optimistic: true
YAML

  include_context "with Host Device"

  it "sends switch commands and receives the updated state" do
    switch = entity_named("Test Switch")
    expect(switch).to be_a(described_class)

    switch.on
    host_device.wait_until do
      expect(switch.state).to be true
    end

    switch.off
    host_device.wait_until do
      expect(switch.state).to be false
    end
  end
end
