# frozen_string_literal: true

module ESPHome
  class Error < StandardError; end

  class DeviceError < Error; end
  class NotConnectedError < Error; end
  class DeviceConnectionError < DeviceError; end
  class AuthenticationError < DeviceError; end
  class InvalidPasswordError < AuthenticationError; end
  class ConnectionClosedError < DeviceConnectionError; end
  class ProtocolError < DeviceError; end
  class PlaintextProtocolError < ProtocolError; end
  class UnknownProtocolError < ProtocolError; end
  class MessageError < DeviceError; end
  class InvalidMessageLengthError < MessageError; end
  class UnknownMessageError < MessageError; end

  class DashboardError < Error; end
  class NoSuchDeviceError < DashboardError; end
  class MissingEncryptionKeyError < DashboardError; end
end
