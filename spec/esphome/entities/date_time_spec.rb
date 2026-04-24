# frozen_string_literal: true

RSpec.describe ESPHome::Entities::DateTime, yaml: <<~YAML do
  datetime:
    - platform: template
      id: test_date_time
      name: Test DateTime
      type: DATETIME
      optimistic: true
      initial_value: 2038-01-19 03:14:08
YAML

  include_context "with Host Device"

  it "sends datetime commands and receives the updated state" do
    date_time = entity_named("Test DateTime")
    expect(date_time).to be_a(described_class)

    host_device.wait_until do
      expect(date_time.state).to eql Time.utc(2038, 1, 19, 3, 14, 8)
    end

    value = Time.utc(2026, 4, 24, 12, 34, 56)
    date_time.command(value)
    host_device.wait_until do
      expect(date_time.state).to eql value
    end
  end
end
