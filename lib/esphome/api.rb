# frozen_string_literal: true

require_relative "api/api_pb"
require_relative "action"
require_relative "entity"

module ESPHome
  module Api
    ID_TO_MESSAGE = [nil,
                     HelloRequest,
                     HelloResponse,
                     ConnectRequest,
                     ConnectResponse,
                     DisconnectRequest,
                     DisconnectResponse,
                     PingRequest,
                     PingResponse,
                     DeviceInfoRequest,
                     DeviceInfoResponse,
                     ListEntitiesRequest,
                     ListEntitiesBinarySensorResponse,
                     ListEntitiesCoverResponse,
                     ListEntitiesFanResponse,
                     ListEntitiesLightResponse,
                     ListEntitiesSensorResponse,
                     ListEntitiesSwitchResponse,
                     ListEntitiesTextSensorResponse,
                     ListEntitiesDoneResponse,
                     SubscribeStatesRequest,
                     BinarySensorStateResponse,
                     CoverStateResponse,
                     FanStateResponse,
                     LightStateResponse,
                     SensorStateResponse,
                     SwitchStateResponse,
                     TextSensorStateResponse,
                     SubscribeLogsRequest,
                     SubscribeLogsResponse,
                     CoverCommandRequest,
                     FanCommandRequest,
                     LightCommandRequest,
                     SwitchCommandRequest,
                     SubscribeHomeassistantServicesRequest,
                     HomeassistantServiceResponse,
                     GetTimeRequest,
                     GetTimeResponse,
                     SubscribeHomeAssistantStatesRequest,
                     SubscribeHomeAssistantStateResponse,
                     HomeAssistantStateResponse,
                     ListEntitiesServicesResponse,
                     ExecuteServiceRequest,
                     ListEntitiesCameraResponse,
                     CameraImageResponse,
                     CameraImageRequest,
                     ListEntitiesClimateResponse,
                     ClimateStateResponse,
                     ClimateCommandRequest,
                     ListEntitiesNumberResponse,
                     NumberStateResponse,
                     NumberCommandRequest,
                     ListEntitiesSelectResponse,
                     SelectStateResponse,
                     SelectCommandRequest,
                     ListEntitiesSirenResponse,
                     SirenStateResponse,
                     SirenCommandRequest,
                     ListEntitiesLockResponse,
                     LockStateResponse,
                     LockCommandRequest,
                     ListEntitiesButtonResponse,
                     ButtonCommandRequest,
                     ListEntitiesMediaPlayerResponse,
                     MediaPlayerStateResponse,
                     MediaPlayerCommandRequest,
                     SubscribeBluetoothLEAdvertisementsRequest,
                     BluetoothLEAdvertisementResponse,
                     BluetoothDeviceRequest,
                     BluetoothDeviceConnectionResponse,
                     BluetoothGATTGetServicesRequest,
                     BluetoothGATTGetServicesResponse,
                     BluetoothGATTGetServicesDoneResponse,
                     BluetoothGATTReadRequest,
                     BluetoothGATTReadResponse,
                     BluetoothGATTWriteRequest,
                     BluetoothGATTReadDescriptorRequest,
                     BluetoothGATTWriteDescriptorRequest,
                     BluetoothGATTNotifyRequest,
                     BluetoothGATTNotifyDataResponse,
                     SubscribeBluetoothConnectionsFreeRequest,
                     BluetoothConnectionsFreeResponse,
                     BluetoothGATTErrorResponse,
                     BluetoothGATTWriteResponse,
                     BluetoothGATTNotifyResponse,
                     BluetoothDevicePairingResponse,
                     BluetoothDeviceUnpairingResponse,
                     UnsubscribeBluetoothLEAdvertisementsRequest,
                     BluetoothDeviceClearCacheResponse,
                     SubscribeVoiceAssistantRequest,
                     VoiceAssistantRequest,
                     VoiceAssistantResponse,
                     VoiceAssistantEventResponse,
                     BluetoothLEAdvertisementResponse,
                     ListEntitiesAlarmControlPanelResponse,
                     AlarmControlPanelStateResponse,
                     AlarmControlPanelCommandRequest,
                     ListEntitiesTextResponse,
                     TextStateResponse,
                     TextCommandRequest,
                     ListEntitiesDateResponse,
                     DateStateResponse,
                     DateCommandRequest,
                     ListEntitiesTimeResponse,
                     TimeStateResponse,
                     TimeCommandRequest,
                     VoiceAssistantAudio,
                     ListEntitiesEventResponse,
                     EventResponse,
                     ListEntitiesValveResponse,
                     ValveStateResponse,
                     ValveCommandRequest,
                     ListEntitiesDateTimeResponse,
                     DateTimeStateResponse,
                     DateTimeCommandRequest,
                     VoiceAssistantTimerEventResponse,
                     ListEntitiesUpdateResponse,
                     UpdateStateResponse,
                     UpdateCommandRequest,
                     VoiceAssistantAnnounceRequest,
                     VoiceAssistantAnnounceFinished,
                     VoiceAssistantConfigurationRequest,
                     VoiceAssistantConfigurationResponse,
                     VoiceAssistantSetConfiguration,
                     NoiseEncryptionSetKeyRequest,
                     NoiseEncryptionSetKeyResponse,
                     BluetoothScannerStateResponse,
                     BluetoothScannerSetModeRequest].each_with_index.filter_map do |klass, index|
      next unless klass

      klass.descriptor.define_singleton_method(:id) { index }

      [index, klass]
    end.to_h.freeze

    def ListEntitiesBinarySensorResponse.entity_class = Entities::BinarySensor
    def ListEntitiesButtonResponse.entity_class = Entities::Button
    def ListEntitiesClimateResponse.entity_class = Entities::Climate
    def ListEntitiesCoverResponse.entity_class = Entities::Cover
    def ListEntitiesDateResponse.entity_class = Entities::Date
    def ListEntitiesDateTimeResponse.entity_class = Entities::DateTime
    def ListEntitiesFanResponse.entity_class = Entities::Fan
    def ListEntitiesLightResponse.entity_class = Entities::Light
    def ListEntitiesLockResponse.entity_class = Entities::Lock
    def ListEntitiesNumberResponse.entity_class = Entities::Number
    def ListEntitiesSelectResponse.entity_class = Entities::Select
    def ListEntitiesSensorResponse.entity_class = Entities::Sensor
    def ListEntitiesSwitchResponse.entity_class = Entities::Switch
    def ListEntitiesTextResponse.entity_class = Entities::Text
    def ListEntitiesTextSensorResponse.entity_class = Entities::TextSensor
    def ListEntitiesTimeResponse.entity_class = Entities::Time
  end
end
