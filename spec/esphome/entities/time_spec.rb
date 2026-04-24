# frozen_string_literal: true

RSpec.describe ESPHome::Entities::Time, yaml: <<~YAML do
  datetime:
    - platform: template
      id: test_time
      name: Test Time
      type: TIME
      optimistic: true
      initial_value: "03:14:08"
YAML

  include_context "with Host Device"

  it "sends time commands and receives the updated state" do
    time = entity_named("Test Time")
    expect(time).to be_a(described_class)

    host_device.wait_until do
      expect(time.state).to eql [3, 14, 8]
    end

    time.command([9, 8, 7])

    host_device.wait_until do
      expect(time.state).to eql [9, 8, 7]
    end
  end
end
