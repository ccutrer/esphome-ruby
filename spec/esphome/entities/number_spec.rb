# frozen_string_literal: true

RSpec.describe ESPHome::Entities::Number, yaml: <<~YAML do
  number:
    - platform: template
      id: test_number
      name: Test Number
      min_value: 40
      max_value: 60
      step: 0.2
      optimistic: true
      initial_value: 42
YAML

  include_context "with Host Device"

  it "sends number commands and receives the updated state" do
    number = entity_named("Test Number")
    expect(number).to be_a(described_class)

    host_device.wait_until do
      expect(number.state).to be_within(0.001).of(42.0)
    end

    number.set(55.4)
    host_device.wait_until do
      expect(number.state).to be_within(0.001).of(55.4)
    end
  end
end
