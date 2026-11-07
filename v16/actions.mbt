// The 1.6J action table: which payload belongs to which action name, and
// which direction it travels. Keeping direction here lets a session reject a
// request that arrives from the wrong side before decoding it.

///|
pub(all) enum Request {
  BootNotification(BootNotification)
  Heartbeat
  Authorize(Authorize)
  StartTransaction(StartTransaction)
  StopTransaction(StopTransaction)
  MeterValues(MeterValues)
  StatusNotification(StatusNotification)
  RemoteStartTransaction(RemoteStartTransaction)
  RemoteStopTransaction(RemoteStopTransaction)
  Reset(Reset)
} derive(Debug, Eq)

///|
pub fn Request::action(self : Request) -> String {
  match self {
    BootNotification(_) => "BootNotification"
    Heartbeat => "Heartbeat"
    Authorize(_) => "Authorize"
    StartTransaction(_) => "StartTransaction"
    StopTransaction(_) => "StopTransaction"
    MeterValues(_) => "MeterValues"
    StatusNotification(_) => "StatusNotification"
    RemoteStartTransaction(_) => "RemoteStartTransaction"
    RemoteStopTransaction(_) => "RemoteStopTransaction"
    Reset(_) => "Reset"
  }
}

///|
pub fn Request::to_json(self : Request) -> Json {
  match self {
    BootNotification(value) => value.to_json()
    Heartbeat => @schema.obj([])
    Authorize(value) => value.to_json()
    StartTransaction(value) => value.to_json()
    StopTransaction(value) => value.to_json()
    MeterValues(value) => value.to_json()
    StatusNotification(value) => value.to_json()
    RemoteStartTransaction(value) => value.to_json()
    RemoteStopTransaction(value) => value.to_json()
    Reset(value) => value.to_json()
  }
}

///|
/// Decode a payload using the action name. Unknown names are reported as
/// `UnknownCode` so callers have one error type for every bad message.
pub fn request_of(action : String, payload : Json) -> Request raise @schema.SchemaError {
  match action {
    "BootNotification" => BootNotification(BootNotification::from_json(payload))
    "Heartbeat" => Heartbeat
    "Authorize" => Authorize(Authorize::from_json(payload))
    "StartTransaction" => StartTransaction(StartTransaction::from_json(payload))
    "StopTransaction" => StopTransaction(StopTransaction::from_json(payload))
    "MeterValues" => MeterValues(MeterValues::from_json(payload))
    "StatusNotification" => StatusNotification(StatusNotification::from_json(payload))
    "RemoteStartTransaction" =>
      RemoteStartTransaction(RemoteStartTransaction::from_json(payload))
    "RemoteStopTransaction" => RemoteStopTransaction(RemoteStopTransaction::from_json(payload))
    "Reset" => Reset(Reset::from_json(payload))
    _ => raise @schema.UnknownCode(action)
  }
}

///|
/// True when the charge point is the sender, false for central system calls.
pub fn from_charge_point(action : String) -> Bool {
  match action {
    "BootNotification" | "Heartbeat" | "Authorize" => true
    "StartTransaction" | "StopTransaction" | "MeterValues" => true
    "StatusNotification" => true
    _ => false
  }
}
