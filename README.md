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
Laundry Room Motion Sensor                    (2025.5.1 - Jun 28 2025, 14:27:10)
================================================================================
Switch - Bluetooth                      : [11:25:26] false
Sensor - Illuminance                    : [11:25:26] 38.4 lx
Number - Max Range                      : [11:25:26] 5400 mm
Number - Min Range                      : [11:25:26] 100 mm
BinarySensor - Presence                 : [11:25:26] false
TextSensor - Radar Bluetooth MAC Address: [11:25:26] unknown
TextSensor - Radar Firmware Version     : [11:25:26] 2.04.23101915
Sensor - Target 1 Angle                 : [11:25:26] 0 °
Sensor - Target 1 Distance              : [11:25:26] 0 mm
Sensor - Target 1 Speed                 : [11:25:26] 0 mm/s
Sensor - Target 1 X                     : [11:25:26] 0 mm
Sensor - Target 1 Y                     : [11:25:26] 0 mm
Sensor - Target 2 Angle                 : [11:25:26] 0 °
Sensor - Target 2 Distance              : [11:25:26] 0 mm
Sensor - Target 2 Speed                 : [11:25:26] 0 mm/s
Sensor - Target 2 X                     : [11:25:26] 0 mm
Sensor - Target 2 Y                     : [11:25:26] 0 mm
Sensor - Target 3 Angle                 : [11:25:26] 0 °
Sensor - Target 3 Distance              : [11:25:26] 0 mm
Sensor - Target 3 Speed                 : [11:25:26] 0 mm/s
Sensor - Target 3 X                     : [11:25:26] 0 mm
Sensor - Target 3 Y                     : [11:25:26] 0 mm
Number - Timeout                        : [11:25:26] 1 s
Sensor - Uptime                         : [11:25:26] 248262 s
Sensor - WiFi Signal Strength           : [11:25:27] -60 dBm

[11:25:26][I][app:115]: ESPHome version 2025.5.1 compiled on Jun 28 2025, 14:27:10
[11:25:26][I][app:117]: Project ccutrer.ld2450 version 1.0
[11:25:26][I][i2c.idf:102]: Results from i2c bus scan:
[11:25:26][I][i2c.idf:108]: Found i2c device at address 0x44
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
