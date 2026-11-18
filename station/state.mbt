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
  mut reservations : Array[(Int, String, Int)]
  mut profiles : Array[(Int, @v16.ChargingProfile)]
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
    profiles: [],
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
/// Reserve a connector. A connector that is charging or already reserved
/// reports Occupied instead of accepting a second reservation.
pub fn ChargePoint::reserve(
  self : ChargePoint,
  id : Int,
  expiry : String,
  connector_id : Int,
) -> String {
  if self.connector != @schema.ConnectorStatus::Available {
    return "Occupied"
  }
  for item in self.reservations {
    if item.2 == connector_id {
      return "Occupied"
    }
  }
  self.reservations.push((id, expiry, connector_id))
  "Accepted"
}

///|
pub fn ChargePoint::cancel_reservation(self : ChargePoint, id : Int) -> Bool {
  let kept : Array[(Int, String, Int)] = []
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
  connector_id : Int,
  profile : @v16.ChargingProfile,
) -> Unit {
  self.profiles.push((connector_id, profile))
}

///|
/// Remove profiles matching the optional filters. A None filter matches every
/// profile; the return value is the number removed.
pub fn ChargePoint::clear_profiles(
  self : ChargePoint,
  id : Int?,
  connector_id : Int?,
  purpose : String?,
  stack_level : Int?,
) -> Int {
  let kept : Array[(Int, @v16.ChargingProfile)] = []
  let mut removed = 0
  for item in self.profiles {
    let profile = item.1
    let mut matches = true
    match id {
      Some(value) => if profile.charging_profile_id != value { matches = false }
      None => ()
    }
    match connector_id {
      Some(value) => if item.0 != value { matches = false }
      None => ()
    }
    match purpose {
      Some(value) =>
        if profile.charging_profile_purpose != value {
          matches = false
        }
      None => ()
    }
    match stack_level {
      Some(value) => if profile.stack_level != value { matches = false }
      None => ()
    }
    if matches {
      removed = removed + 1
    } else {
      kept.push(item)
    }
  }
  self.profiles = kept
  removed
}

///|
/// The composite schedule is the highest stack level for the connector; the
/// periods of that profile are returned unchanged. This is the documented
/// selection rule, not a full constraint solver.
pub fn ChargePoint::composite_schedule(
  self : ChargePoint,
  connector_id : Int,
) -> @v16.ChargingSchedule? {
  let mut best : @v16.ChargingProfile? = None
  for item in self.profiles {
    if item.0 == connector_id {
      match best {
        None => best = Some(item.1)
        Some(current) =>
          if item.1.stack_level > current.stack_level {
            best = Some(item.1)
          }
      }
    }
  }
  match best {
    Some(profile) => Some(profile.charging_schedule)
    None => None
  }
}

///|
pub fn ChargePoint::profile_count(self : ChargePoint) -> Int {
  self.profiles.length()
}
