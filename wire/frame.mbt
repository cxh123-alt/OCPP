// OCPP rides on JSON-RPC 2.0 but does not use the named-object form: every
// message is a positional array whose first element is 2, 3 or 4. This
// package owns that array and nothing about charging semantics.

///|
/// Everything that can go wrong before a payload is looked at.
pub(all) suberror WireError {
  NotAnArray
  WrongArity(Int)
  UnknownType(Double)
  MissingField(String)
  WrongFieldType(String)
  InvalidJson
}

///|
pub(all) struct Call {
  id : String
  action : String
  payload : Json
} derive(Debug, Eq)

///|
pub(all) struct CallResult {
  id : String
  payload : Json
} derive(Debug, Eq)

///|
pub(all) struct CallError {
  id : String
  code : String
  description : String
  details : Json
} derive(Debug, Eq)

///|
/// A parsed OCPP frame. The three shapes map to the three JSON-RPC message
/// types OCPP allows.
pub(all) enum Frame {
  Call(Call)
  Result(CallResult)
  Failure(CallError)
} derive(Debug, Eq)

///|
pub fn parse(text : String) -> Frame raise WireError {
  let root = @json.parse(text) catch { _ => raise InvalidJson }
  let items = match root {
    Json::Array(items) => items
    _ => raise NotAnArray
  }
  if items.length() < 3 {
    raise WrongArity(items.length())
  }
  let kind = match items[0] {
    Json::Number(value, ..) => value
    _ => raise WrongFieldType("messageType")
  }
  if kind == 2.0 {
    if items.length() != 4 {
      raise WrongArity(items.length())
    }
    let payload = items[3]
    require_object(payload, "payload")
    Frame::Call({
      id: require_string(items[1], "messageId"),
      action: require_string(items[2], "action"),
      payload,
    })
  } else if kind == 3.0 {
    if items.length() != 3 {
      raise WrongArity(items.length())
    }
    Frame::Result({
      id: require_string(items[1], "messageId"),
      payload: items[2],
    })
  } else if kind == 4.0 {
    if items.length() != 5 {
      raise WrongArity(items.length())
    }
    Frame::Failure({
      id: require_string(items[1], "messageId"),
      code: require_string(items[2], "errorCode"),
      description: require_string(items[3], "errorDescription"),
      details: items[4],
    })
  } else {
    raise UnknownType(kind)
  }
}

///|
pub fn encode(frame : Frame) -> String {
  match frame {
    Call(call) =>
      Json::array([
        Json::number(2.0),
        Json::string(call.id),
        Json::string(call.action),
        call.payload,
      ]).stringify()
    Result(result) =>
      Json::array([Json::number(3.0), Json::string(result.id), result.payload]).stringify()
    Failure(failure) =>
      Json::array([
        Json::number(4.0),
        Json::string(failure.id),
        Json::string(failure.code),
        Json::string(failure.description),
        failure.details,
      ]).stringify()
  }
}

///|
fn require_string(json : Json, field : String) -> String raise WireError {
  match json {
    Json::String(value) => value
    _ => raise WrongFieldType(field)
  }
}

///|
fn require_object(json : Json, field : String) -> Unit raise WireError {
  match json {
    Json::Object(_) => ()
    _ => raise WrongFieldType(field)
  }
}
