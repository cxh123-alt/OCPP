// 2.0.1 action table. Authorize is special: the body nests the token under
// `idToken`, unlike the 1.6 string field, so it is wrapped here rather than
// inside the token type.

///|
pub(all) enum Request {
  BootNotification(BootNotification)
  Heartbeat
  Authorize(IdToken)
  TransactionEvent(TransactionEvent)
  MeterValues(MeterValues)
  StatusNotification(StatusNotification)
  RequestStartTransaction(RequestStartTransaction)
  RequestStopTransaction(RequestStopTransaction)
  Reset(Reset)
} derive(Debug, Eq)

///|
pub fn Request::action(self : Request) -> String {
  match self {
    BootNotification(_) => "BootNotification"
    Heartbeat => "Heartbeat"
    Authorize(_) => "Authorize"
    TransactionEvent(_) => "TransactionEvent"
    MeterValues(_) => "MeterValues"
    StatusNotification(_) => "StatusNotification"
    RequestStartTransaction(_) => "RequestStartTransaction"
    RequestStopTransaction(_) => "RequestStopTransaction"
    Reset(_) => "Reset"
  }
}

///|
pub fn Request::to_json(self : Request) -> Json {
  match self {
    BootNotification(value) => value.to_json()
    Heartbeat => @schema.obj([])
    Authorize(token) => @schema.obj([("idToken", token.to_json())])
    TransactionEvent(value) => value.to_json()
    MeterValues(value) => value.to_json()
    StatusNotification(value) => value.to_json()
    RequestStartTransaction(value) => value.to_json()
    RequestStopTransaction(value) => value.to_json()
    Reset(value) => value.to_json()
  }
}

///|
pub fn request_of(action : String, payload : Json) -> Request raise @schema.SchemaError {
  match action {
    "BootNotification" => BootNotification(BootNotification::from_json(payload))
    "Heartbeat" => Heartbeat
    "Authorize" => Authorize(IdToken::from_json(@schema.get_object(payload, "idToken")))
    "TransactionEvent" => TransactionEvent(TransactionEvent::from_json(payload))
    "MeterValues" => MeterValues(MeterValues::from_json(payload))
    "StatusNotification" => StatusNotification(StatusNotification::from_json(payload))
    "RequestStartTransaction" =>
      RequestStartTransaction(RequestStartTransaction::from_json(payload))
    "RequestStopTransaction" => RequestStopTransaction(RequestStopTransaction::from_json(payload))
    "Reset" => Reset(Reset::from_json(payload))
    _ => raise @schema.UnknownCode(action)
  }
}

///|
pub fn from_charge_point(action : String) -> Bool {
  match action {
    "BootNotification" | "Heartbeat" | "Authorize" => true
    "TransactionEvent" | "MeterValues" | "StatusNotification" => true
    _ => false
  }
}
