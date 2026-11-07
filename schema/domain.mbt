// Values shared by both protocol versions. Where 1.6 and 2.0.1 disagree the
// code uses two types rather than one type with a version flag, because the
// wire names differ and a silent mismatch is the usual source of bugs.

///|
pub(all) enum RegistrationStatus {
  Accepted
  Pending
  Rejected
} derive(Debug, Eq)

///|
pub fn RegistrationStatus::code(self : RegistrationStatus) -> String {
  match self {
    Accepted => "Accepted"
    Pending => "Pending"
    Rejected => "Rejected"
  }
}

///|
pub fn registration_status(text : String) -> RegistrationStatus? {
  match text {
    "Accepted" => Some(Accepted)
    "Pending" => Some(Pending)
    "Rejected" => Some(Rejected)
    _ => None
  }
}

///|
pub(all) enum AuthorizationStatus {
  Accepted
  Blocked
  Expired
  Invalid
  ConcurrentTx
} derive(Debug, Eq)

///|
pub fn AuthorizationStatus::code(self : AuthorizationStatus) -> String {
  match self {
    Accepted => "Accepted"
    Blocked => "Blocked"
    Expired => "Expired"
    Invalid => "Invalid"
    ConcurrentTx => "ConcurrentTx"
  }
}

///|
pub fn authorization_status(text : String) -> AuthorizationStatus? {
  match text {
    "Accepted" => Some(Accepted)
    "Blocked" => Some(Blocked)
    "Expired" => Some(Expired)
    "Invalid" => Some(Invalid)
    "ConcurrentTx" => Some(ConcurrentTx)
    _ => None
  }
}

///|
pub(all) enum ConnectorStatus {
  Available
  Preparing
  Charging
  SuspendedEVSE
  SuspendedEV
  Finishing
  Reserved
  Unavailable
  Faulted
} derive(Debug, Eq)

///|
pub fn ConnectorStatus::code(self : ConnectorStatus) -> String {
  match self {
    Available => "Available"
    Preparing => "Preparing"
    Charging => "Charging"
    SuspendedEVSE => "SuspendedEVSE"
    SuspendedEV => "SuspendedEV"
    Finishing => "Finishing"
    Reserved => "Reserved"
    Unavailable => "Unavailable"
    Faulted => "Faulted"
  }
}

///|
pub fn connector_status(text : String) -> ConnectorStatus? {
  match text {
    "Available" => Some(Available)
    "Preparing" => Some(Preparing)
    "Charging" => Some(Charging)
    "SuspendedEVSE" => Some(SuspendedEVSE)
    "SuspendedEV" => Some(SuspendedEV)
    "Finishing" => Some(Finishing)
    "Reserved" => Some(Reserved)
    "Unavailable" => Some(Unavailable)
    "Faulted" => Some(Faulted)
    _ => None
  }
}

///|
pub(all) enum TransactionEventKind {
  Started
  Updated
  Ended
} derive(Debug, Eq)

///|
pub fn TransactionEventKind::code(self : TransactionEventKind) -> String {
  match self {
    Started => "Started"
    Updated => "Updated"
    Ended => "Ended"
  }
}

///|
pub fn transaction_event_kind(text : String) -> TransactionEventKind? {
  match text {
    "Started" => Some(Started)
    "Updated" => Some(Updated)
    "Ended" => Some(Ended)
    _ => None
  }
}

///|
pub(all) enum ResetKind {
  Soft
  Hard
} derive(Debug, Eq)

///|
pub fn ResetKind::code(self : ResetKind) -> String {
  match self {
    Soft => "Soft"
    Hard => "Hard"
  }
}

///|
pub fn reset_kind(text : String) -> ResetKind? {
  match text {
    "Soft" => Some(Soft)
    "Hard" => Some(Hard)
    _ => None
  }
}

///|
pub(all) enum RequestStatus {
  Accepted
  Rejected
} derive(Debug, Eq)

///|
pub fn RequestStatus::code(self : RequestStatus) -> String {
  match self {
    Accepted => "Accepted"
    Rejected => "Rejected"
  }
}

///|
pub fn request_status(text : String) -> RequestStatus? {
  match text {
    "Accepted" => Some(Accepted)
    "Rejected" => Some(Rejected)
    _ => None
  }
}

///|
/// The 2.0.1 `chargingStation` object.
pub(all) struct ChargingStation {
  model : String
  vendor : String
  serial_number : String?
  firmware_version : String?
} derive(Debug, Eq)

///|
pub fn ChargingStation::to_json(self : ChargingStation) -> Json {
  let fields : Array[(String, Json)] = [
    ("model", text(self.model)),
    ("vendor", text(self.vendor)),
  ]
  match self.serial_number {
    Some(value) => fields.push(("serialNumber", text(value)))
    None => ()
  }
  match self.firmware_version {
    Some(value) => fields.push(("firmwareVersion", text(value)))
    None => ()
  }
  obj(fields)
}

///|
pub fn ChargingStation::from_json(
  json : Json,
) -> ChargingStation raise SchemaError {
  {
    model: get_string(json, "model"),
    vendor: get_string(json, "vendor"),
    serial_number: opt_string(json, "serialNumber"),
    firmware_version: opt_string(json, "firmwareVersion"),
  }
}

///|
/// A UTC timestamp with the second precision OCPP uses.
pub(all) struct ClockTime {
  year : Int
  month : Int
  day : Int
  hour : Int
  minute : Int
  second : Int
} derive(Debug, Eq)

///|
pub fn ClockTime::iso(self : ClockTime) -> String {
  let out = StringBuilder()
  push_padded(out, self.year, 4)
  out.write_char('-')
  push_padded(out, self.month, 2)
  out.write_char('-')
  push_padded(out, self.day, 2)
  out.write_char('T')
  push_padded(out, self.hour, 2)
  out.write_char(':')
  push_padded(out, self.minute, 2)
  out.write_char(':')
  push_padded(out, self.second, 2)
  out.write_char('Z')
  out.to_string()
}

///|
fn push_padded(out : StringBuilder, value : Int, width : Int) -> Unit {
  let mut divisor = 1
  for _ in 1..<width {
    divisor = divisor * 10
  }
  let mut rest = value
  while divisor > 0 {
    let digit = rest / divisor
    rest = rest % divisor
    out.write_char(Int::unsafe_to_char(48 + digit))
    divisor = divisor / 10
  }
}

///|
pub fn ClockTime::advance(self : ClockTime, seconds : Int) -> ClockTime {
  let total = self.hour * 3600 + self.minute * 60 + self.second + seconds
  {
    year: self.year,
    month: self.month,
    day: self.day,
    hour: total / 3600 % 24,
    minute: total / 60 % 60,
    second: total % 60,
  }
}

///|
pub(all) enum ConfigurationStatus {
  Accepted
  Rejected
  RebootRequired
  NotSupported
} derive(Debug, Eq)

///|
pub fn ConfigurationStatus::code(self : ConfigurationStatus) -> String {
  match self {
    Accepted => "Accepted"
    Rejected => "Rejected"
    RebootRequired => "RebootRequired"
    NotSupported => "NotSupported"
  }
}

///|
pub fn configuration_status(text : String) -> ConfigurationStatus? {
  match text {
    "Accepted" => Some(Accepted)
    "Rejected" => Some(Rejected)
    "RebootRequired" => Some(RebootRequired)
    "NotSupported" => Some(NotSupported)
    _ => None
  }
}