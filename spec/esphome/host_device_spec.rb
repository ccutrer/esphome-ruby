# frozen_string_literal: true

RSpec.describe ESPHome::HostDevice do
  it "raises a config error with command output when the YAML is malformed" do
    host_device = described_class.new(<<~YAML)
      button: [
    YAML

    expect { host_device.start }
      .to raise_error(ESPHome::HostDevice::ConfigError) { |error|
        expect(error.output).to include("Invalid YAML syntax")
      }
  ensure
    host_device&.stop
  end

  it "raises a compile error with command output when generated code does not compile" do
    host_device = described_class.new(<<~YAML)
      interval:
        - interval: 1s
          then:
            - lambda: |-
                this_symbol_should_not_compile = 1;
    YAML

    expect { host_device.start }
      .to raise_error(ESPHome::HostDevice::CompileError) { |error|
        expect(error.output).to include("this_symbol_should_not_compile")
        expect(error.output).to match(/error:/i)
      }
  ensure
    host_device&.stop
  end

  it "waits for log lines" do
    host_device = described_class.new
    host_device.log(Logger::INFO, "api log line")

    expect(host_device.wait_for_log_line("api log line", timeout: 0.01)).to eql ["api log line"]
  end
end
