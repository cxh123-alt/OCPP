// The charge point's own state: which connector is doing what and how much
// energy has gone through it. Frames are built on top of this, never the other
// way round.

///|
pub(all) enum Version {
  V16
} derive(Debug, Eq)

///|
pub fn Version::label(self : Version) -> String {
  match self {
    V16 => "1.6J"
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
  mut meter_wh : Int
  mut local_list_version : Int
  mut local_list : Array[String]
  mut reservations : Array[(Int, String)]
  mut charging_profile : @v16.ChargingProfile?
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
    meter_wh: 0,
    local_list_version: 0,
    local_list: [],
    reservations: [],
    charging_profile: None,
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
  match self.transaction_16 {
    Some(value) => value.to_string()
    None => "-"
  }
}

///|
pub fn ChargePoint::begin_transaction(self : ChargePoint, id : Int) -> Unit {
  self.transaction_16 = Some(id)
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

///|
/// Replace or extend the local authorization list. The returned version is the
/// one a GetLocalListVersion call will report.
pub fn ChargePoint::set_local_list(
  self : ChargePoint,
  version : Int,
  tags : Array[String],
  update_type : String,
) -> Unit {
  if update_type == "Full" {
    self.local_list = tags
  } else {
    for tag in tags {
      self.local_list.push(tag)
    }
  }
  self.local_list_version = version
}

///|
pub fn ChargePoint::local_list_version(self : ChargePoint) -> Int {
  self.local_list_version
}

///|
/// Store a reservation. Expiry is kept as the protocol string so callers can
/// pass it through unchanged.
pub fn ChargePoint::reserve(
  self : ChargePoint,
  id : Int,
  expiry : String,
) -> Unit {
  self.reservations.push((id, expiry))
}

///|
pub fn ChargePoint::cancel_reservation(self : ChargePoint, id : Int) -> Bool {
  let kept : Array[(Int, String)] = []
  let mut found = false
  for item in self.reservations {
    if item.0 == id {
      found = true
    } else {
      kept.push(item)
    }
  }
  self.reservations = kept
  found
}

///|
pub fn ChargePoint::reservation_count(self : ChargePoint) -> Int {
  self.reservations.length()
}

///|
pub fn ChargePoint::set_profile(
  self : ChargePoint,
  profile : @v16.ChargingProfile,
) -> Unit {
  self.charging_profile = Some(profile)
}

///|
pub fn ChargePoint::clear_profile(self : ChargePoint) -> Unit {
  self.charging_profile = None
}

///|
pub fn ChargePoint::profile_schedule(
  self : ChargePoint,
) -> @v16.ChargingSchedule? {
  match self.charging_profile {
    Some(profile) => Some(profile.charging_schedule)
    None => None
  }
}
