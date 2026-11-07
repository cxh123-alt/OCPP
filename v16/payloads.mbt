// OCPP 1.6J payloads. The shapes are the ones a charger and a central system
// actually exchange in the core profile; optional fields that are rarely
// populated are kept optional rather than dropped, so a conforming peer can
// still send them.

///|
pub(all) struct IdTagInfo {
  status : @schema.AuthorizationStatus
  expiry_date : String?
  parent_id_tag : String?
} derive(Debug, Eq)

///|
pub fn IdTagInfo::to_json(self : IdTagInfo) -> Json {
  let fields : Array[(String, Json)] = [
    ("status", @schema.text(self.status.code())),
  ]
  match self.expiry_date {
    Some(value) => fields.push(("expiryDate", @schema.text(value)))
    None => ()
  }
  match self.parent_id_tag {
    Some(value) => fields.push(("parentIdTag", @schema.text(value)))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn IdTagInfo::from_json(json : Json) -> IdTagInfo raise @schema.SchemaError {
  let status_text = @schema.get_string(json, "status")
  let status = match @schema.authorization_status(status_text) {
    Some(value) => value
    None => raise @schema.UnknownCode(status_text)
  }
  {
    status,
    expiry_date: @schema.opt_string(json, "expiryDate"),
    parent_id_tag: @schema.opt_string(json, "parentIdTag"),
  }
}

///|
pub(all) struct BootNotification {
  charge_point_model : String
  charge_point_vendor : String
  charge_point_serial_number : String?
  firmware_version : String?
  iccid : String?
  imsi : String?
  meter_serial_number : String?
  meter_type : String?
} derive(Debug, Eq)

///|
pub fn BootNotification::to_json(self : BootNotification) -> Json {
  let fields : Array[(String, Json)] = [
    ("chargePointModel", @schema.text(self.charge_point_model)),
    ("chargePointVendor", @schema.text(self.charge_point_vendor)),
  ]
  push_opt(fields, "chargePointSerialNumber", self.charge_point_serial_number)
  push_opt(fields, "firmwareVersion", self.firmware_version)
  push_opt(fields, "iccid", self.iccid)
  push_opt(fields, "imsi", self.imsi)
  push_opt(fields, "meterSerialNumber", self.meter_serial_number)
  push_opt(fields, "meterType", self.meter_type)
  @schema.obj(fields)
}

///|
pub fn BootNotification::from_json(
  json : Json,
) -> BootNotification raise @schema.SchemaError {
  {
    charge_point_model: @schema.get_string(json, "chargePointModel"),
    charge_point_vendor: @schema.get_string(json, "chargePointVendor"),
    charge_point_serial_number: @schema.opt_string(
      json, "chargePointSerialNumber",
    ),
    firmware_version: @schema.opt_string(json, "firmwareVersion"),
    iccid: @schema.opt_string(json, "iccid"),
    imsi: @schema.opt_string(json, "imsi"),
    meter_serial_number: @schema.opt_string(json, "meterSerialNumber"),
    meter_type: @schema.opt_string(json, "meterType"),
  }
}

///|
pub(all) struct BootNotificationResponse {
  status : @schema.RegistrationStatus
  current_time : String
  interval : Int
} derive(Debug, Eq)

///|
pub fn BootNotificationResponse::to_json(
  self : BootNotificationResponse,
) -> Json {
  @schema.obj([
    ("status", @schema.text(self.status.code())),
    ("currentTime", @schema.text(self.current_time)),
    ("interval", @schema.integer(self.interval)),
  ])
}

///|
pub fn BootNotificationResponse::from_json(
  json : Json,
) -> BootNotificationResponse raise @schema.SchemaError {
  let status_text = @schema.get_string(json, "status")
  let status = match @schema.registration_status(status_text) {
    Some(value) => value
    None => raise @schema.UnknownCode(status_text)
  }
  {
    status,
    current_time: @schema.get_string(json, "currentTime"),
    interval: @schema.get_int(json, "interval"),
  }
}

///|
pub(all) struct HeartbeatResponse {
  current_time : String
} derive(Debug, Eq)

///|
pub fn HeartbeatResponse::to_json(self : HeartbeatResponse) -> Json {
  @schema.obj([("currentTime", @schema.text(self.current_time))])
}

///|
pub fn HeartbeatResponse::from_json(
  json : Json,
) -> HeartbeatResponse raise @schema.SchemaError {
  { current_time: @schema.get_string(json, "currentTime"), }
}

///|
pub(all) struct Authorize {
  id_tag : String
} derive(Debug, Eq)

///|
pub fn Authorize::to_json(self : Authorize) -> Json {
  @schema.obj([("idTag", @schema.text(self.id_tag))])
}

///|
pub fn Authorize::from_json(json : Json) -> Authorize raise @schema.SchemaError {
  { id_tag: @schema.get_string(json, "idTag"), }
}

///|
pub(all) struct AuthorizeResponse {
  id_tag_info : IdTagInfo
} derive(Debug, Eq)

///|
pub fn AuthorizeResponse::to_json(self : AuthorizeResponse) -> Json {
  @schema.obj([("idTagInfo", self.id_tag_info.to_json())])
}

///|
pub fn AuthorizeResponse::from_json(
  json : Json,
) -> AuthorizeResponse raise @schema.SchemaError {
  { id_tag_info: IdTagInfo::from_json(@schema.get_object(json, "idTagInfo")), }
}

///|
pub(all) struct StartTransaction {
  connector_id : Int
  id_tag : String
  meter_start : Int
  reservation_id : Int?
  timestamp : String
} derive(Debug, Eq)

///|
pub fn StartTransaction::to_json(self : StartTransaction) -> Json {
  let fields : Array[(String, Json)] = [
    ("connectorId", @schema.integer(self.connector_id)),
    ("idTag", @schema.text(self.id_tag)),
    ("meterStart", @schema.integer(self.meter_start)),
    ("timestamp", @schema.text(self.timestamp)),
  ]
  match self.reservation_id {
    Some(value) => fields.push(("reservationId", @schema.integer(value)))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn StartTransaction::from_json(
  json : Json,
) -> StartTransaction raise @schema.SchemaError {
  {
    connector_id: @schema.get_int(json, "connectorId"),
    id_tag: @schema.get_string(json, "idTag"),
    meter_start: @schema.get_int(json, "meterStart"),
    reservation_id: @schema.opt_int(json, "reservationId"),
    timestamp: @schema.get_string(json, "timestamp"),
  }
}

///|
pub(all) struct StartTransactionResponse {
  transaction_id : Int
  id_tag_info : IdTagInfo
} derive(Debug, Eq)

///|
pub fn StartTransactionResponse::to_json(
  self : StartTransactionResponse,
) -> Json {
  @schema.obj([
    ("transactionId", @schema.integer(self.transaction_id)),
    ("idTagInfo", self.id_tag_info.to_json()),
  ])
}

///|
pub fn StartTransactionResponse::from_json(
  json : Json,
) -> StartTransactionResponse raise @schema.SchemaError {
  {
    transaction_id: @schema.get_int(json, "transactionId"),
    id_tag_info: IdTagInfo::from_json(@schema.get_object(json, "idTagInfo")),
  }
}

///|
pub(all) struct StopTransaction {
  transaction_id : Int
  meter_stop : Int
  timestamp : String
  reason : String?
} derive(Debug, Eq)

///|
pub fn StopTransaction::to_json(self : StopTransaction) -> Json {
  let fields : Array[(String, Json)] = [
    ("transactionId", @schema.integer(self.transaction_id)),
    ("meterStop", @schema.integer(self.meter_stop)),
    ("timestamp", @schema.text(self.timestamp)),
  ]
  match self.reason {
    Some(value) => fields.push(("reason", @schema.text(value)))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn StopTransaction::from_json(
  json : Json,
) -> StopTransaction raise @schema.SchemaError {
  {
    transaction_id: @schema.get_int(json, "transactionId"),
    meter_stop: @schema.get_int(json, "meterStop"),
    timestamp: @schema.get_string(json, "timestamp"),
    reason: @schema.opt_string(json, "reason"),
  }
}

///|
pub(all) struct StopTransactionResponse {
  id_tag_info : IdTagInfo?
} derive(Debug, Eq)

///|
pub fn StopTransactionResponse::to_json(self : StopTransactionResponse) -> Json {
  let fields : Array[(String, Json)] = []
  match self.id_tag_info {
    Some(value) => fields.push(("idTagInfo", value.to_json()))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn StopTransactionResponse::from_json(
  json : Json,
) -> StopTransactionResponse raise @schema.SchemaError {
  let fields = @schema.object_of(json)
  let info = if fields.contains("idTagInfo") {
    Some(IdTagInfo::from_json(@schema.get_object(json, "idTagInfo")))
  } else {
    None
  }
  { id_tag_info: info, }
}

///|
pub(all) struct SampledValue {
  value : String
  measurand : String?
  context : String?
  format : String?
  unit : String?
} derive(Debug, Eq)

///|
pub fn SampledValue::to_json(self : SampledValue) -> Json {
  let fields : Array[(String, Json)] = [("value", @schema.text(self.value))]
  match self.measurand {
    Some(value) => fields.push(("measurand", @schema.text(value)))
    None => ()
  }
  match self.context {
    Some(value) => fields.push(("context", @schema.text(value)))
    None => ()
  }
  match self.format {
    Some(value) => fields.push(("format", @schema.text(value)))
    None => ()
  }
  match self.unit {
    Some(value) => fields.push(("unit", @schema.text(value)))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn SampledValue::from_json(
  json : Json,
) -> SampledValue raise @schema.SchemaError {
  {
    value: @schema.get_string(json, "value"),
    measurand: @schema.opt_string(json, "measurand"),
    context: @schema.opt_string(json, "context"),
    format: @schema.opt_string(json, "format"),
    unit: @schema.opt_string(json, "unit"),
  }
}

///|
pub(all) struct MeterValue {
  timestamp : String
  sampled_value : Array[SampledValue]
} derive(Debug, Eq)

///|
pub fn MeterValue::to_json(self : MeterValue) -> Json {
  let samples : Array[Json] = []
  for sample in self.sampled_value {
    samples.push(sample.to_json())
  }
  @schema.obj([
    ("timestamp", @schema.text(self.timestamp)),
    ("sampledValue", Json::array(samples)),
  ])
}

///|
pub fn MeterValue::from_json(
  json : Json,
) -> MeterValue raise @schema.SchemaError {
  let items = @schema.get_array(json, "sampledValue")
  let samples : Array[SampledValue] = []
  for item in items {
    samples.push(SampledValue::from_json(item))
  }
  { timestamp: @schema.get_string(json, "timestamp"), sampled_value: samples, }
}

///|
pub(all) struct MeterValues {
  connector_id : Int
  transaction_id : Int?
  meter_value : Array[MeterValue]
} derive(Debug, Eq)

///|
pub fn MeterValues::to_json(self : MeterValues) -> Json {
  let values : Array[Json] = []
  for value in self.meter_value {
    values.push(value.to_json())
  }
  let fields : Array[(String, Json)] = [
    ("connectorId", @schema.integer(self.connector_id)),
    ("meterValue", Json::array(values)),
  ]
  match self.transaction_id {
    Some(value) => fields.push(("transactionId", @schema.integer(value)))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn MeterValues::from_json(
  json : Json,
) -> MeterValues raise @schema.SchemaError {
  let items = @schema.get_array(json, "meterValue")
  let values : Array[MeterValue] = []
  for item in items {
    values.push(MeterValue::from_json(item))
  }
  {
    connector_id: @schema.get_int(json, "connectorId"),
    transaction_id: @schema.opt_int(json, "transactionId"),
    meter_value: values,
  }
}

///|
pub(all) struct StatusNotification {
  connector_id : Int
  error_code : String
  status : @schema.ConnectorStatus
  timestamp : String?
} derive(Debug, Eq)

///|
pub fn StatusNotification::to_json(self : StatusNotification) -> Json {
  let fields : Array[(String, Json)] = [
    ("connectorId", @schema.integer(self.connector_id)),
    ("errorCode", @schema.text(self.error_code)),
    ("status", @schema.text(self.status.code())),
  ]
  match self.timestamp {
    Some(value) => fields.push(("timestamp", @schema.text(value)))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn StatusNotification::from_json(
  json : Json,
) -> StatusNotification raise @schema.SchemaError {
  let status_text = @schema.get_string(json, "status")
  let status = match @schema.connector_status(status_text) {
    Some(value) => value
    None => raise @schema.UnknownCode(status_text)
  }
  {
    connector_id: @schema.get_int(json, "connectorId"),
    error_code: @schema.get_string(json, "errorCode"),
    status,
    timestamp: @schema.opt_string(json, "timestamp"),
  }
}

///|
pub(all) struct RemoteStartTransaction {
  id_tag : String
  connector_id : Int?
} derive(Debug, Eq)

///|
pub fn RemoteStartTransaction::to_json(self : RemoteStartTransaction) -> Json {
  let fields : Array[(String, Json)] = [("idTag", @schema.text(self.id_tag))]
  match self.connector_id {
    Some(value) => fields.push(("connectorId", @schema.integer(value)))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn RemoteStartTransaction::from_json(
  json : Json,
) -> RemoteStartTransaction raise @schema.SchemaError {
  {
    id_tag: @schema.get_string(json, "idTag"),
    connector_id: @schema.opt_int(json, "connectorId"),
  }
}

///|
pub(all) struct RemoteStopTransaction {
  transaction_id : Int
} derive(Debug, Eq)

///|
pub fn RemoteStopTransaction::to_json(self : RemoteStopTransaction) -> Json {
  @schema.obj([("transactionId", @schema.integer(self.transaction_id))])
}

///|
pub fn RemoteStopTransaction::from_json(
  json : Json,
) -> RemoteStopTransaction raise @schema.SchemaError {
  { transaction_id: @schema.get_int(json, "transactionId"), }
}

///|
pub(all) struct Reset {
  kind : @schema.ResetKind
} derive(Debug, Eq)

///|
pub fn Reset::to_json(self : Reset) -> Json {
  @schema.obj([("type", @schema.text(self.kind.code()))])
}

///|
pub fn Reset::from_json(json : Json) -> Reset raise @schema.SchemaError {
  let kind_text = @schema.get_string(json, "type")
  let kind = match @schema.reset_kind(kind_text) {
    Some(value) => value
    None => raise @schema.UnknownCode(kind_text)
  }
  { kind, }
}

///|
pub(all) struct RequestStatusResponse {
  status : @schema.RequestStatus
} derive(Debug, Eq)

///|
pub fn RequestStatusResponse::to_json(self : RequestStatusResponse) -> Json {
  @schema.obj([("status", @schema.text(self.status.code()))])
}

///|
pub fn RequestStatusResponse::from_json(
  json : Json,
) -> RequestStatusResponse raise @schema.SchemaError {
  let status_text = @schema.get_string(json, "status")
  let status = match @schema.request_status(status_text) {
    Some(value) => value
    None => raise @schema.UnknownCode(status_text)
  }
  { status, }
}

///|
fn push_opt(
  fields : Array[(String, Json)],
  key : String,
  value : String?,
) -> Unit {
  match value {
    Some(text) => fields.push((key, @schema.text(text)))
    None => ()
  }
}

///|
pub(all) struct ChangeConfiguration {
  key : String
  value : String
} derive(Debug, Eq)

///|
pub fn ChangeConfiguration::to_json(self : ChangeConfiguration) -> Json {
  @schema.obj([
    ("key", @schema.text(self.key)),
    ("value", @schema.text(self.value)),
  ])
}

///|
pub fn ChangeConfiguration::from_json(
  json : Json,
) -> ChangeConfiguration raise @schema.SchemaError {
  {
    key: @schema.get_string(json, "key"),
    value: @schema.get_string(json, "value"),
  }
}

///|
pub(all) struct ConfigurationKey {
  key : String
  is_readonly : Bool
  value : String?
} derive(Debug, Eq)

///|
pub fn ConfigurationKey::to_json(self : ConfigurationKey) -> Json {
  let fields : Array[(String, Json)] = [
    ("key", @schema.text(self.key)),
    ("readonly", @schema.boolean(self.is_readonly)),
  ]
  match self.value {
    Some(value) => fields.push(("value", @schema.text(value)))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn ConfigurationKey::from_json(
  json : Json,
) -> ConfigurationKey raise @schema.SchemaError {
  {
    key: @schema.get_string(json, "key"),
    is_readonly: @schema.get_bool(json, "readonly"),
    value: @schema.opt_string(json, "value"),
  }
}

///|
pub(all) struct GetConfiguration {
  keys : Array[String]?
} derive(Debug, Eq)

///|
pub fn GetConfiguration::to_json(self : GetConfiguration) -> Json {
  let fields : Array[(String, Json)] = []
  match self.keys {
    Some(keys) => {
      let items : Array[Json] = []
      for key in keys {
        items.push(@schema.text(key))
      }
      fields.push(("key", Json::array(items)))
    }
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn GetConfiguration::from_json(
  json : Json,
) -> GetConfiguration raise @schema.SchemaError {
  let keys = match @schema.opt_array(json, "key") {
    Some(items) => {
      let result : Array[String] = []
      for item in items {
        match item {
          Json::String(value) => result.push(value)
          _ => raise @schema.WrongType("key")
        }
      }
      Some(result)
    }
    None => None
  }
  { keys, }
}

///|
pub(all) struct GetConfigurationResponse {
  configuration_key : Array[ConfigurationKey]
  unknown_key : Array[String]?
} derive(Debug, Eq)

///|
pub fn GetConfigurationResponse::to_json(
  self : GetConfigurationResponse,
) -> Json {
  let items : Array[Json] = []
  for key in self.configuration_key {
    items.push(key.to_json())
  }
  let fields : Array[(String, Json)] = [
    ("configurationKey", Json::array(items)),
  ]
  match self.unknown_key {
    Some(keys) => {
      let raw : Array[Json] = []
      for key in keys {
        raw.push(@schema.text(key))
      }
      fields.push(("unknownKey", Json::array(raw)))
    }
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn GetConfigurationResponse::from_json(
  json : Json,
) -> GetConfigurationResponse raise @schema.SchemaError {
  let entries = @schema.get_array(json, "configurationKey")
  let configuration_key : Array[ConfigurationKey] = []
  for entry in entries {
    configuration_key.push(ConfigurationKey::from_json(entry))
  }
  let unknown_key = match @schema.opt_array(json, "unknownKey") {
    Some(entries) => {
      let keys : Array[String] = []
      for entry in entries {
        match entry {
          Json::String(value) => keys.push(value)
          _ => raise @schema.WrongType("unknownKey")
        }
      }
      Some(keys)
    }
    None => None
  }
  { configuration_key, unknown_key, }
}

///|
pub(all) struct RemoteTrigger {
  requested_message : String
} derive(Debug, Eq)

///|
pub fn RemoteTrigger::to_json(self : RemoteTrigger) -> Json {
  @schema.obj([("requestedMessage", @schema.text(self.requested_message))])
}

///|
pub fn RemoteTrigger::from_json(
  json : Json,
) -> RemoteTrigger raise @schema.SchemaError {
  { requested_message: @schema.get_string(json, "requestedMessage"), }
}

///|
pub(all) struct ChangeConfigurationResponse {
  status : @schema.ConfigurationStatus
} derive(Debug, Eq)

///|
pub fn ChangeConfigurationResponse::to_json(
  self : ChangeConfigurationResponse,
) -> Json {
  @schema.obj([("status", @schema.text(self.status.code()))])
}

///|
pub fn ChangeConfigurationResponse::from_json(
  json : Json,
) -> ChangeConfigurationResponse raise @schema.SchemaError {
  let status_text = @schema.get_string(json, "status")
  let status = match @schema.configuration_status(status_text) {
    Some(value) => value
    None => raise @schema.UnknownCode(status_text)
  }
  { status, }
}

///|
pub(all) struct GetDiagnostics {
  location : String?
  retries : Int?
  retry_interval : Int?
  start_time : String?
  stop_time : String?
} derive(Debug, Eq)

///|
pub fn GetDiagnostics::to_json(self : GetDiagnostics) -> Json {
  let fields : Array[(String, Json)] = []
  match self.location {
    Some(value) => fields.push(("location", @schema.text(value)))
    None => ()
  }
  match self.retries {
    Some(value) => fields.push(("retries", @schema.integer(value)))
    None => ()
  }
  match self.retry_interval {
    Some(value) => fields.push(("retryInterval", @schema.integer(value)))
    None => ()
  }
  match self.start_time {
    Some(value) => fields.push(("startTime", @schema.text(value)))
    None => ()
  }
  match self.stop_time {
    Some(value) => fields.push(("stopTime", @schema.text(value)))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn GetDiagnostics::from_json(json : Json) -> GetDiagnostics raise @schema.SchemaError {
  {
    location: @schema.opt_string(json, "location"),
    retries: @schema.opt_int(json, "retries"),
    retry_interval: @schema.opt_int(json, "retryInterval"),
    start_time: @schema.opt_string(json, "startTime"),
    stop_time: @schema.opt_string(json, "stopTime"),
  }
}

///|
pub(all) struct GetDiagnosticsResponse {
  file_name : String?
} derive(Debug, Eq)

///|
pub fn GetDiagnosticsResponse::to_json(self : GetDiagnosticsResponse) -> Json {
  let fields : Array[(String, Json)] = []
  match self.file_name {
    Some(value) => fields.push(("fileName", @schema.text(value)))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn GetDiagnosticsResponse::from_json(
  json : Json,
) -> GetDiagnosticsResponse raise @schema.SchemaError {
  { file_name: @schema.opt_string(json, "fileName") }
}

///|
pub(all) struct DiagnosticsStatusNotification {
  status : String
} derive(Debug, Eq)

///|
pub fn DiagnosticsStatusNotification::to_json(self : DiagnosticsStatusNotification) -> Json {
  @schema.obj([("status", @schema.text(self.status))])
}

///|
pub fn DiagnosticsStatusNotification::from_json(
  json : Json,
) -> DiagnosticsStatusNotification raise @schema.SchemaError {
  { status: @schema.get_string(json, "status") }
}

///|
pub(all) struct FirmwareStatusNotification {
  status : String
} derive(Debug, Eq)

///|
pub fn FirmwareStatusNotification::to_json(self : FirmwareStatusNotification) -> Json {
  @schema.obj([("status", @schema.text(self.status))])
}

///|
pub fn FirmwareStatusNotification::from_json(
  json : Json,
) -> FirmwareStatusNotification raise @schema.SchemaError {
  { status: @schema.get_string(json, "status") }
}