# frozen_string_literal: true

RSpec.describe ESPHome::Entities::Lock, yaml: <<~YAML do
  lock:
    - platform: template
      id: test_lock
      name: Test Lock
      optimistic: true
      assumed_state: true
      lock_action:
        - lock.template.publish:
            id: test_lock
            state: LOCKED
      unlock_action:
        - lock.template.publish:
            id: test_lock
            state: UNLOCKED
      open_action:
        - lock.template.publish:
            id: test_lock
            state: UNLOCKED
YAML

  include_context "with Host Device"

  it "sends lock commands and receives the updated state" do
    lock = entity_named("Test Lock")
    expect(lock).to be_a(described_class)

    lock.unlock
    host_device.wait_until do
      expect(lock.state).to be :unlocked
    end

    lock.lock
    host_device.wait_until do
      expect(lock.state).to be :locked
    end

    lock.open
    host_device.wait_until do
      expect(lock.state).to be :unlocked
    end
  end
end
