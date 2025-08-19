# ESPHome Ruby Library

This is a Ruby library to interact directly with [ESPHome](https://esphome.io/) using the [native API](https://esphome.io/components/api.html).
It can be used as a library as part of another application, or as a CLI for directly interacting with devices if the device doesn't have a web server or MQTT connection.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add esphome
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install esphome
```

## Usage

Use the CLI to continously monitor entity states and the log:
```bash
$> esphome-monitor <host-name> <encryption-key>
```

```
ESPHome
Laundry Room Motion Sensor                      2025.7.5 - Aug 18 2025, 16:55:47
================================================================================
Bluetooth                   : off                                     [14:30:30]
Factory Reset Radar         : PRESS
Illuminance                 : 47.1 lx                                 [14:30:30]
Max Range                   : 5400 mm                                 [14:30:30]
Min Range                   : 300 mm                                  [14:30:30]
Presence                    : not occupied                            [14:30:30]
Radar Bluetooth MAC Address : unknown                                 [14:30:30]
Radar Firmware Version      : 2.04.23101915                           [14:30:30]
Restart                     : PRESS
Restart Radar               : PRESS
Target 1 Angle              : 0 °                                     [14:30:30]
Target 1 Distance           : 0 mm                                    [14:30:30]
Target 1 Speed              : 0 mm/s                                  [14:30:30]
Target 1 X                  : 0 mm                                    [14:30:30]
Target 1 Y                  : 0 mm                                    [14:30:30]
Target 2 Angle              : 0 °                                     [14:30:30]
Target 2 Distance           : 0 mm                                    [14:30:30]
Target 2 Speed              : 0 mm/s                                  [14:30:30]
Target 2 X                  : 0 mm                                    [14:30:30]
Target 2 Y                  : 0 mm                                    [14:30:30]
Target 3 Angle              : 0 °                                     [14:30:30]
Target 3 Distance           : 0 mm                                    [14:30:30]
Target 3 Speed              : 0 mm/s                                  [14:30:30]
Target 3 X                  : 0 mm                                    [14:30:30]
Target 3 Y                  : 0 mm                                    [14:30:30]
Timeout                     : 1 s                                     [14:30:30]
Uptime                      : 77611 s                                 [14:30:31]
WiFi Signal Strength        : -72 dBm                                 [14:30:34]

[14:30:29] Connected
[14:30:30] [I][app:149]: ESPHome version 2025.7.5 compiled on Aug 18 2025, 16:55:47
[14:30:30] [I][app:151]: Project ccutrer.ld2450 version 1.0
[14:30:30] [I][i2c.idf:104]: Results from bus scan:
[14:30:30] [I][i2c.idf:110]: Found device at address 0x44
```

## Unsupported Entities

 * Alarm Control Panel
 * Camera
 * Event
 * Media Player
 * Services
 * Siren
 * Update
 * Valve

## Partially Supported Entities

These entities can be parsed and state shown, but not have commands sent to them:

 * Climate
 * Fan
 * Light

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ccutrer/esphome-ruby.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
