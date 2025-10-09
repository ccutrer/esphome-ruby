Just copy api.proto from esphome's repository, re-add `option ruby_package = "ESPHome::Api";` at the top, and remove `(pointer_to_buffer) = true` options.
Then regenerate with `protoc --ruby_out=. api.proto api_options.proto`, and finally edit the `require` in api_pb.rb to be `require_relative`.
