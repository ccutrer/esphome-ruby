Just copy api.proto from esphome's repository and re-add `option ruby_package = "ESPHome::Api";` at the top.
Then regenerate with `protoc --ruby_out=. api.proto api_options.proto`, and finally edit the `require` in api_pb.rb to be `require_relative`.
Be sure to add any new messages to api.rb, and check for changes in the messages themselves.
