// The charge point's own state: which connector is doing what, how much
// energy has gone through it, and which protocol revision it speaks. Frames
// are built on top of this, never the other way round.

///|
pub(all) enum Version {
  V16
  V2
} derive(Debug, Eq)

///|
pub fn Version::label(self : Version) -> String {
  match self {
    V16 => "1.6J"
    V2 => "2.0.1"
  }
}

///|
pub(all) struct ChargePoint {
  id : String
  vendor : String
  model : String
  version : Version
  mut serial : Int
  mut connector : @schema.ConnectorStatus
  mut transaction_16 : Int?
  mut transaction_2 : String?
  mut seq_no : Int
  mut meter_wh : Int
  mut booted : Bool
} derive(Debug, Eq)

///|
pub fn ChargePoint::new(id : String, version : Version) -> ChargePoint {
  {
    id,
    vendor: "MoonCharge",
    model: "MC-7",
    version,
    serial: 0,
    connector: @schema.ConnectorStatus::Available,
    transaction_16: None,
    transaction_2: None,
    seq_no: 0,
    meter_wh: 0,
    booted: false,
  }
}

///|
fn ChargePoint::next_serial(self : ChargePoint) -> Int {
  self.serial = self.serial + 1
  self.serial
}

///|
fn ChargePoint::message_id(self : ChargePoint) -> String {
  ignore(self.next_serial())
  self.id + "-" + self.serial.to_string()
}

///|
pub fn ChargePoint::is_charging(self : ChargePoint) -> Bool {
  self.connector == @schema.ConnectorStatus::Charging
}

///|
pub fn ChargePoint::transaction_label(self : ChargePoint) -> String {
  match self.version {
    V16 =>
      match self.transaction_16 {
        Some(value) => value.to_string()
        None => "-"
      }
    V2 =>
      match self.transaction_2 {
        Some(value) => value
        None => "-"
      }
  }
}

///|
pub fn ChargePoint::begin_transaction(self : ChargePoint, id : Int) -> Unit {
  match self.version {
    V16 => self.transaction_16 = Some(id)
    V2 => {
      self.transaction_2 = Some("TX-" + id.to_string())
      self.seq_no = 1
    }
  }
  self.connector = @schema.ConnectorStatus::Charging
}

///|
pub fn ChargePoint::end_transaction(self : ChargePoint) -> Unit {
  self.connector = @schema.ConnectorStatus::Finishing
}

///|
pub fn ChargePoint::add_energy(self : ChargePoint, wh : Int) -> Unit {
  self.meter_wh = self.meter_wh + wh
}
