// OCPP 2.0.1 payloads. The shape changed enough from 1.6 that sharing types
// would hide real differences: identity is an object, a transaction is a
// stream of events, and responses are keyed differently.

///|
pub(all) enum BootReason {
  PowerUp
  ApplicationReset
  FirmwareUpdate
  LocalReset
  RemoteReset
  ScheduledReset
  Triggered
  Watchdog
  Unknown
} derive(Debug, Eq)

///|
pub fn BootReason::code(self : BootReason) -> String {
  match self {
    PowerUp => "PowerUp"
    ApplicationReset => "ApplicationReset"
    FirmwareUpdate => "FirmwareUpdate"
    LocalReset => "LocalReset"
    RemoteReset => "RemoteReset"
    ScheduledReset => "ScheduledReset"
    Triggered => "Triggered"
    Watchdog => "Watchdog"
    Unknown => "Unknown"
  }
}

///|
pub fn boot_reason(text : String) -> BootReason? {
  match text {
    "PowerUp" => Some(PowerUp)
    "ApplicationReset" => Some(ApplicationReset)
    "FirmwareUpdate" => Some(FirmwareUpdate)
    "LocalReset" => Some(LocalReset)
    "RemoteReset" => Some(RemoteReset)
    "ScheduledReset" => Some(ScheduledReset)
    "Triggered" => Some(Triggered)
    "Watchdog" => Some(Watchdog)
    "Unknown" => Some(Unknown)
    _ => None
  }
}

///|
pub(all) enum IdTokenKind {
  Central
  Emaid
  Iso14443
  Iso15693
  KeyCode
  Local
  MacAddress
  NoAuthorization
} derive(Debug, Eq)

///|
pub fn IdTokenKind::code(self : IdTokenKind) -> String {
  match self {
    Central => "Central"
    Emaid => "eMAID"
    Iso14443 => "ISO14443"
    Iso15693 => "ISO15693"
    KeyCode => "KeyCode"
    Local => "Local"
    MacAddress => "MacAddress"
    NoAuthorization => "NoAuthorization"
  }
}

///|
pub fn id_token_kind(text : String) -> IdTokenKind? {
  match text {
    "Central" => Some(Central)
    "eMAID" => Some(Emaid)
    "ISO14443" => Some(Iso14443)
    "ISO15693" => Some(Iso15693)
    "KeyCode" => Some(KeyCode)
    "Local" => Some(Local)
    "MacAddress" => Some(MacAddress)
    "NoAuthorization" => Some(NoAuthorization)
    _ => None
  }
}

///|
pub(all) struct IdToken {
  value : String
  kind : IdTokenKind
} derive(Debug, Eq)

///|
pub fn IdToken::to_json(self : IdToken) -> Json {
  @schema.obj([
    ("idToken", @schema.text(self.value)),
    ("type", @schema.text(self.kind.code())),
  ])
}

///|
pub fn IdToken::from_json(json : Json) -> IdToken raise @schema.SchemaError {
  let kind_text = @schema.get_string(json, "type")
  let kind = match id_token_kind(kind_text) {
    Some(value) => value
    None => raise @schema.UnknownCode(kind_text)
  }
  { value: @schema.get_string(json, "idToken"), kind, }
}

///|
pub(all) struct IdTokenInfo {
  status : @schema.AuthorizationStatus
  cache_expiry : String?
} derive(Debug, Eq)

///|
pub fn IdTokenInfo::to_json(self : IdTokenInfo) -> Json {
  let fields : Array[(String, Json)] = [
    ("status", @schema.text(self.status.code())),
  ]
  match self.cache_expiry {
    Some(value) => fields.push(("cacheExpiryDateTime", @schema.text(value)))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn IdTokenInfo::from_json(
  json : Json,
) -> IdTokenInfo raise @schema.SchemaError {
  let status_text = @schema.get_string(json, "status")
  let status = match @schema.authorization_status(status_text) {
    Some(value) => value
    None => raise @schema.UnknownCode(status_text)
  }
  { status, cache_expiry: @schema.opt_string(json, "cacheExpiryDateTime"), }
}

///|
pub(all) struct BootNotification {
  reason : BootReason
  station : @schema.ChargingStation
} derive(Debug, Eq)

///|
pub fn BootNotification::to_json(self : BootNotification) -> Json {
  @schema.obj([
    ("reason", @schema.text(self.reason.code())),
    ("chargingStation", self.station.to_json()),
  ])
}

///|
pub fn BootNotification::from_json(
  json : Json,
) -> BootNotification raise @schema.SchemaError {
  let reason_text = @schema.get_string(json, "reason")
  let reason = match boot_reason(reason_text) {
    Some(value) => value
    None => raise @schema.UnknownCode(reason_text)
  }
  {
    reason,
    station: @schema.ChargingStation::from_json(
      @schema.get_object(json, "chargingStation"),
    ),
  }
}

///|
pub(all) struct BootNotificationResponse {
  current_time : String
  interval : Int
  status : @schema.RegistrationStatus
} derive(Debug, Eq)

///|
pub fn BootNotificationResponse::to_json(
  self : BootNotificationResponse,
) -> Json {
  @schema.obj([
    ("currentTime", @schema.text(self.current_time)),
    ("interval", @schema.integer(self.interval)),
    ("status", @schema.text(self.status.code())),
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
    current_time: @schema.get_string(json, "currentTime"),
    interval: @schema.get_int(json, "interval"),
    status,
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
pub(all) struct AuthorizeResponse {
  id_token_info : IdTokenInfo
} derive(Debug, Eq)

///|
pub fn AuthorizeResponse::to_json(self : AuthorizeResponse) -> Json {
  @schema.obj([("idTokenInfo", self.id_token_info.to_json())])
}

///|
pub fn AuthorizeResponse::from_json(
  json : Json,
) -> AuthorizeResponse raise @schema.SchemaError {
  {
    id_token_info: IdTokenInfo::from_json(
      @schema.get_object(json, "idTokenInfo"),
    ),
  }
}

///|
pub(all) struct SampledValue {
  value : String
  measurand : String?
  context : String?
  phase : String?
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
  match self.phase {
    Some(value) => fields.push(("phase", @schema.text(value)))
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
    phase: @schema.opt_string(json, "phase"),
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
pub(all) struct TransactionInfo {
  transaction_id : String
  charging_state : String?
  stopped_reason : String?
} derive(Debug, Eq)

///|
pub fn TransactionInfo::to_json(self : TransactionInfo) -> Json {
  let fields : Array[(String, Json)] = [
    ("transactionId", @schema.text(self.transaction_id)),
  ]
  match self.charging_state {
    Some(value) => fields.push(("chargingState", @schema.text(value)))
    None => ()
  }
  match self.stopped_reason {
    Some(value) => fields.push(("stoppedReason", @schema.text(value)))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn TransactionInfo::from_json(
  json : Json,
) -> TransactionInfo raise @schema.SchemaError {
  {
    transaction_id: @schema.get_string(json, "transactionId"),
    charging_state: @schema.opt_string(json, "chargingState"),
    stopped_reason: @schema.opt_string(json, "stoppedReason"),
  }
}

///|
pub(all) struct TransactionEvent {
  event_type : @schema.TransactionEventKind
  timestamp : String
  trigger_reason : String
  seq_no : Int
  transaction_info : TransactionInfo
  id_token : IdToken?
  evse_id : Int?
  meter_value : Array[MeterValue]?
} derive(Debug, Eq)

///|
pub fn TransactionEvent::to_json(self : TransactionEvent) -> Json {
  let fields : Array[(String, Json)] = [
    ("eventType", @schema.text(self.event_type.code())),
    ("timestamp", @schema.text(self.timestamp)),
    ("triggerReason", @schema.text(self.trigger_reason)),
    ("seqNo", @schema.integer(self.seq_no)),
    ("transactionInfo", self.transaction_info.to_json()),
  ]
  match self.id_token {
    Some(value) => fields.push(("idToken", value.to_json()))
    None => ()
  }
  match self.evse_id {
    Some(value) =>
      fields.push(("evse", @schema.obj([("id", @schema.integer(value))])))
    None => ()
  }
  match self.meter_value {
    Some(values) => {
      let items : Array[Json] = []
      for value in values {
        items.push(value.to_json())
      }
      fields.push(("meterValue", Json::array(items)))
    }
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn TransactionEvent::from_json(
  json : Json,
) -> TransactionEvent raise @schema.SchemaError {
  let kind_text = @schema.get_string(json, "eventType")
  let event_type = match @schema.transaction_event_kind(kind_text) {
    Some(value) => value
    None => raise @schema.UnknownCode(kind_text)
  }
  let id_token = match @schema.object_of(json).get("idToken") {
    Some(value) => Some(IdToken::from_json(value))
    None => None
  }
  let evse_id = match @schema.object_of(json).get("evse") {
    Some(value) => Some(@schema.get_int(value, "id"))
    None => None
  }
  let meter_value = match @schema.opt_array(json, "meterValue") {
    Some(items) => {
      let values : Array[MeterValue] = []
      for item in items {
        values.push(MeterValue::from_json(item))
      }
      Some(values)
    }
    None => None
  }
  {
    event_type,
    timestamp: @schema.get_string(json, "timestamp"),
    trigger_reason: @schema.get_string(json, "triggerReason"),
    seq_no: @schema.get_int(json, "seqNo"),
    transaction_info: TransactionInfo::from_json(
      @schema.get_object(json, "transactionInfo"),
    ),
    id_token,
    evse_id,
    meter_value,
  }
}

///|
pub(all) struct TransactionEventResponse {
  id_token_info : IdTokenInfo?
} derive(Debug, Eq)

///|
pub fn TransactionEventResponse::to_json(
  self : TransactionEventResponse,
) -> Json {
  let fields : Array[(String, Json)] = []
  match self.id_token_info {
    Some(value) => fields.push(("idTokenInfo", value.to_json()))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn TransactionEventResponse::from_json(
  json : Json,
) -> TransactionEventResponse raise @schema.SchemaError {
  let info = match @schema.object_of(json).get("idTokenInfo") {
    Some(value) => Some(IdTokenInfo::from_json(value))
    None => None
  }
  { id_token_info: info, }
}

///|
pub(all) struct StatusNotification {
  timestamp : String
  connector_status : @schema.ConnectorStatus
  evse_id : Int
  connector_id : Int
} derive(Debug, Eq)

///|
pub fn StatusNotification::to_json(self : StatusNotification) -> Json {
  @schema.obj([
    ("timestamp", @schema.text(self.timestamp)),
    ("connectorStatus", @schema.text(self.connector_status.code())),
    ("evseId", @schema.integer(self.evse_id)),
    ("connectorId", @schema.integer(self.connector_id)),
  ])
}

///|
pub fn StatusNotification::from_json(
  json : Json,
) -> StatusNotification raise @schema.SchemaError {
  let status_text = @schema.get_string(json, "connectorStatus")
  let connector_status = match @schema.connector_status(status_text) {
    Some(value) => value
    None => raise @schema.UnknownCode(status_text)
  }
  {
    timestamp: @schema.get_string(json, "timestamp"),
    connector_status,
    evse_id: @schema.get_int(json, "evseId"),
    connector_id: @schema.get_int(json, "connectorId"),
  }
}

///|
pub(all) struct MeterValues {
  evse_id : Int
  meter_value : Array[MeterValue]
} derive(Debug, Eq)

///|
pub fn MeterValues::to_json(self : MeterValues) -> Json {
  let items : Array[Json] = []
  for value in self.meter_value {
    items.push(value.to_json())
  }
  @schema.obj([
    ("evseId", @schema.integer(self.evse_id)),
    ("meterValue", Json::array(items)),
  ])
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
  { evse_id: @schema.get_int(json, "evseId"), meter_value: values, }
}

///|
pub(all) struct RequestStartTransaction {
  id_token : IdToken
  remote_start_id : Int
  evse_id : Int?
} derive(Debug, Eq)

///|
pub fn RequestStartTransaction::to_json(self : RequestStartTransaction) -> Json {
  let fields : Array[(String, Json)] = [
    ("idToken", self.id_token.to_json()),
    ("remoteStartId", @schema.integer(self.remote_start_id)),
  ]
  match self.evse_id {
    Some(value) => fields.push(("evseId", @schema.integer(value)))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn RequestStartTransaction::from_json(
  json : Json,
) -> RequestStartTransaction raise @schema.SchemaError {
  {
    id_token: IdToken::from_json(@schema.get_object(json, "idToken")),
    remote_start_id: @schema.get_int(json, "remoteStartId"),
    evse_id: @schema.opt_int(json, "evseId"),
  }
}

///|
pub(all) struct RequestStartResponse {
  status : @schema.RequestStatus
  transaction_id : String?
} derive(Debug, Eq)

///|
pub fn RequestStartResponse::to_json(self : RequestStartResponse) -> Json {
  let fields : Array[(String, Json)] = [
    ("status", @schema.text(self.status.code())),
  ]
  match self.transaction_id {
    Some(value) => fields.push(("transactionId", @schema.text(value)))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn RequestStartResponse::from_json(
  json : Json,
) -> RequestStartResponse raise @schema.SchemaError {
  let status_text = @schema.get_string(json, "status")
  let status = match @schema.request_status(status_text) {
    Some(value) => value
    None => raise @schema.UnknownCode(status_text)
  }
  { status, transaction_id: @schema.opt_string(json, "transactionId"), }
}

///|
pub(all) struct RequestStopTransaction {
  transaction_id : String
} derive(Debug, Eq)

///|
pub fn RequestStopTransaction::to_json(self : RequestStopTransaction) -> Json {
  @schema.obj([("transactionId", @schema.text(self.transaction_id))])
}

///|
pub fn RequestStopTransaction::from_json(
  json : Json,
) -> RequestStopTransaction raise @schema.SchemaError {
  { transaction_id: @schema.get_string(json, "transactionId"), }
}

///|
pub(all) struct Reset {
  kind : @schema.ResetKind
  evse_id : Int?
} derive(Debug, Eq)

///|
pub fn Reset::to_json(self : Reset) -> Json {
  let fields : Array[(String, Json)] = [
    ("type", @schema.text(self.kind.code())),
  ]
  match self.evse_id {
    Some(value) => fields.push(("evseId", @schema.integer(value)))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn Reset::from_json(json : Json) -> Reset raise @schema.SchemaError {
  let kind_text = @schema.get_string(json, "type")
  let kind = match @schema.reset_kind(kind_text) {
    Some(value) => value
    None => raise @schema.UnknownCode(kind_text)
  }
  { kind, evse_id: @schema.opt_int(json, "evseId"), }
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
pub(all) struct Component {
  name : String
  instance : String?
} derive(Debug, Eq)

///|
pub fn Component::to_json(self : Component) -> Json {
  let fields : Array[(String, Json)] = [("name", @schema.text(self.name))]
  match self.instance {
    Some(value) => fields.push(("instance", @schema.text(value)))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn Component::from_json(json : Json) -> Component raise @schema.SchemaError {
  {
    name: @schema.get_string(json, "name"),
    instance: @schema.opt_string(json, "instance"),
  }
}

///|
pub(all) struct Variable {
  name : String
  instance : String?
} derive(Debug, Eq)

///|
pub fn Variable::to_json(self : Variable) -> Json {
  let fields : Array[(String, Json)] = [("name", @schema.text(self.name))]
  match self.instance {
    Some(value) => fields.push(("instance", @schema.text(value)))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn Variable::from_json(json : Json) -> Variable raise @schema.SchemaError {
  {
    name: @schema.get_string(json, "name"),
    instance: @schema.opt_string(json, "instance"),
  }
}

///|
pub(all) struct GetVariableData {
  component : Component
  variable : Variable
  attribute_type : String?
} derive(Debug, Eq)

///|
pub fn GetVariableData::to_json(self : GetVariableData) -> Json {
  let fields : Array[(String, Json)] = [
    ("component", self.component.to_json()),
    ("variable", self.variable.to_json()),
  ]
  match self.attribute_type {
    Some(value) => fields.push(("attributeType", @schema.text(value)))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn GetVariableData::from_json(
  json : Json,
) -> GetVariableData raise @schema.SchemaError {
  {
    component: Component::from_json(@schema.get_object(json, "component")),
    variable: Variable::from_json(@schema.get_object(json, "variable")),
    attribute_type: @schema.opt_string(json, "attributeType"),
  }
}

///|
pub(all) struct GetVariables {
  items : Array[GetVariableData]
} derive(Debug, Eq)

///|
pub fn GetVariables::to_json(self : GetVariables) -> Json {
  let items : Array[Json] = []
  for item in self.items {
    items.push(item.to_json())
  }
  @schema.obj([("getVariableData", Json::array(items))])
}

///|
pub fn GetVariables::from_json(
  json : Json,
) -> GetVariables raise @schema.SchemaError {
  let raw = @schema.get_array(json, "getVariableData")
  let items : Array[GetVariableData] = []
  for item in raw {
    items.push(GetVariableData::from_json(item))
  }
  { items, }
}

///|
pub(all) struct GetVariableResult {
  attribute_type : String?
  attribute_status : String
  component : Component
  variable : Variable
  attribute_value : String?
} derive(Debug, Eq)

///|
pub fn GetVariableResult::to_json(self : GetVariableResult) -> Json {
  let fields : Array[(String, Json)] = [
    ("attributeStatus", @schema.text(self.attribute_status)),
    ("component", self.component.to_json()),
    ("variable", self.variable.to_json()),
  ]
  match self.attribute_type {
    Some(value) => fields.push(("attributeType", @schema.text(value)))
    None => ()
  }
  match self.attribute_value {
    Some(value) => fields.push(("attributeValue", @schema.text(value)))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn GetVariableResult::from_json(
  json : Json,
) -> GetVariableResult raise @schema.SchemaError {
  {
    attribute_type: @schema.opt_string(json, "attributeType"),
    attribute_status: @schema.get_string(json, "attributeStatus"),
    component: Component::from_json(@schema.get_object(json, "component")),
    variable: Variable::from_json(@schema.get_object(json, "variable")),
    attribute_value: @schema.opt_string(json, "attributeValue"),
  }
}

///|
pub(all) struct GetVariablesResponse {
  results : Array[GetVariableResult]
} derive(Debug, Eq)

///|
pub fn GetVariablesResponse::to_json(self : GetVariablesResponse) -> Json {
  let items : Array[Json] = []
  for item in self.results {
    items.push(item.to_json())
  }
  @schema.obj([("getVariableResult", Json::array(items))])
}

///|
pub fn GetVariablesResponse::from_json(
  json : Json,
) -> GetVariablesResponse raise @schema.SchemaError {
  let raw = @schema.get_array(json, "getVariableResult")
  let results : Array[GetVariableResult] = []
  for item in raw {
    results.push(GetVariableResult::from_json(item))
  }
  { results, }
}

///|
pub(all) struct SetVariableData {
  attribute_type : String?
  attribute_value : String
  component : Component
  variable : Variable
} derive(Debug, Eq)

///|
pub fn SetVariableData::to_json(self : SetVariableData) -> Json {
  let fields : Array[(String, Json)] = [
    ("attributeValue", @schema.text(self.attribute_value)),
    ("component", self.component.to_json()),
    ("variable", self.variable.to_json()),
  ]
  match self.attribute_type {
    Some(value) => fields.push(("attributeType", @schema.text(value)))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn SetVariableData::from_json(
  json : Json,
) -> SetVariableData raise @schema.SchemaError {
  {
    attribute_type: @schema.opt_string(json, "attributeType"),
    attribute_value: @schema.get_string(json, "attributeValue"),
    component: Component::from_json(@schema.get_object(json, "component")),
    variable: Variable::from_json(@schema.get_object(json, "variable")),
  }
}

///|
pub(all) struct SetVariables {
  items : Array[SetVariableData]
} derive(Debug, Eq)

///|
pub fn SetVariables::to_json(self : SetVariables) -> Json {
  let items : Array[Json] = []
  for item in self.items {
    items.push(item.to_json())
  }
  @schema.obj([("setVariableData", Json::array(items))])
}

///|
pub fn SetVariables::from_json(
  json : Json,
) -> SetVariables raise @schema.SchemaError {
  let raw = @schema.get_array(json, "setVariableData")
  let items : Array[SetVariableData] = []
  for item in raw {
    items.push(SetVariableData::from_json(item))
  }
  { items, }
}

///|
pub(all) struct SetVariableResult {
  attribute_type : String?
  attribute_status : String
  component : Component
  variable : Variable
} derive(Debug, Eq)

///|
pub fn SetVariableResult::to_json(self : SetVariableResult) -> Json {
  let fields : Array[(String, Json)] = [
    ("attributeStatus", @schema.text(self.attribute_status)),
    ("component", self.component.to_json()),
    ("variable", self.variable.to_json()),
  ]
  match self.attribute_type {
    Some(value) => fields.push(("attributeType", @schema.text(value)))
    None => ()
  }
  @schema.obj(fields)
}

///|
pub fn SetVariableResult::from_json(
  json : Json,
) -> SetVariableResult raise @schema.SchemaError {
  {
    attribute_type: @schema.opt_string(json, "attributeType"),
    attribute_status: @schema.get_string(json, "attributeStatus"),
    component: Component::from_json(@schema.get_object(json, "component")),
    variable: Variable::from_json(@schema.get_object(json, "variable")),
  }
}

///|
pub(all) struct SetVariablesResponse {
  results : Array[SetVariableResult]
} derive(Debug, Eq)

///|
pub fn SetVariablesResponse::to_json(self : SetVariablesResponse) -> Json {
  let items : Array[Json] = []
  for item in self.results {
    items.push(item.to_json())
  }
  @schema.obj([("setVariableResult", Json::array(items))])
}

///|
pub fn SetVariablesResponse::from_json(
  json : Json,
) -> SetVariablesResponse raise @schema.SchemaError {
  let raw = @schema.get_array(json, "setVariableResult")
  let results : Array[SetVariableResult] = []
  for item in raw {
    results.push(SetVariableResult::from_json(item))
  }
  { results, }
}
