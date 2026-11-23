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
  mut config : Array[(String, String)]
  mut auth_cache : Array[String]
  mut firmware : (String, String)?
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
    config: [
      ("WebSocketPingInterval", "60"),
      ("MeterValueSampleInterval", "300"),
    ],
    auth_cache: [],
    firmware: None,
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
  match self.connector {
    @schema.ConnectorStatus::Available => ()
    @schema.ConnectorStatus::Unavailable => return "Unavailable"
    @schema.ConnectorStatus::Faulted => return "Faulted"
    _ => return "Occupied"
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
/// The composite schedule is computed over `[now, now + duration)`. At every
/// boundary the highest stack level among the profiles that cover that instant
/// wins; a profile whose validTo or schedule duration ends mid-window gives way
/// to the lower profile, so the returned periods contain the fallback.
pub fn ChargePoint::composite_schedule(
  self : ChargePoint,
  connector_id : Int,
  now : String,
  duration : Int,
) -> @v16.ChargingSchedule? {
  let now_epoch = match parse_iso(now) {
    Some(value) => value
    None => return None
  }
  if duration <= 0 {
    return None
  }
  let horizon = now_epoch + duration
  let points : Array[Int] = [0, duration]
  for item in self.profiles {
    if item.0 == connector_id {
      let profile = item.1
      match profile.valid_to {
        Some(value) =>
          match parse_iso(value) {
            Some(epoch) =>
              if epoch > now_epoch && epoch < horizon {
                points.push(epoch - now_epoch)
              }
            None => ()
          }
        None => ()
      }
      match profile.charging_schedule.start_schedule {
        Some(value) =>
          match parse_iso(value) {
            Some(start) => {
              let end = match profile.charging_schedule.duration {
                Some(span) => start + span
                None => horizon
              }
              if end > now_epoch && end < horizon {
                points.push(end - now_epoch)
              }
            }
            None => ()
          }
        None => ()
      }
      for period in profile.charging_schedule.charging_schedule_period {
        if period.start_period > 0 && period.start_period < duration {
          points.push(period.start_period)
        }
      }
    }
  }
  let ordered = unique_sorted(points)
  let periods : Array[@v16.ChargingSchedulePeriod] = []
  let mut unit = "A"
  for index in 0..<(ordered.length() - 1) {
    let offset = ordered[index]
    let at = now_epoch + offset
    let station = self.select_profile(0, "ChargePointMaxProfile", at, now_epoch)
    let tx = match
      self.select_profile(connector_id, "TxProfile", at, now_epoch) {
      Some(profile) => Some(profile)
      None =>
        self.select_profile(connector_id, "TxDefaultProfile", at, now_epoch)
    }
    let station_limit = match station {
      Some(profile) => limit_at(profile, at, now_epoch)
      None => None
    }
    let tx_limit = match tx {
      Some(profile) => limit_at(profile, at, now_epoch)
      None => None
    }
    let limit = match (station_limit, tx_limit) {
      (Some(station_value), Some(tx_value)) =>
        Some(if station_value < tx_value { station_value } else { tx_value })
      (Some(value), None) => Some(value)
      (None, Some(value)) => Some(value)
      (None, None) => None
    }
    match limit {
      Some(value) => {
        let unit_profile = match tx {
          Some(profile) => Some(profile)
          None => station
        }
        match unit_profile {
          Some(profile) => unit = profile.charging_schedule.charging_rate_unit
          None => ()
        }
        let duplicate = if periods.length() > 0 {
          periods[periods.length() - 1].limit == value
        } else {
          false
        }
        if !duplicate {
          periods.push({
            start_period: offset,
            limit: value,
            number_phases: None,
          })
        }
      }
      None => ()
    }
  }
  if periods.length() == 0 {
    return None
  }
  let schedule : @v16.ChargingSchedule = {
    duration: Some(duration),
    start_schedule: Some(now),
    charging_rate_unit: unit,
    charging_schedule_period: periods,
    min_charging_rate: None,
  }
  Some(schedule)
}

///|
/// Highest stack level for one purpose at one instant. ChargePointMaxProfile is
/// stored on connector 0; transaction profiles are stored per connector.
fn ChargePoint::select_profile(
  self : ChargePoint,
  connector_id : Int,
  purpose : String,
  at : Int,
  now_epoch : Int,
) -> @v16.ChargingProfile? {
  let mut best : @v16.ChargingProfile? = None
  for item in self.profiles {
    if item.0 == connector_id &&
      item.1.charging_profile_purpose == purpose &&
      profile_covers(item.1, at, now_epoch) {
      match best {
        None => best = Some(item.1)
        Some(current) =>
          if item.1.stack_level > current.stack_level {
            best = Some(item.1)
          }
      }
    }
  }
  best
}

///|
fn profile_covers(
  profile : @v16.ChargingProfile,
  at : Int,
  now_epoch : Int,
) -> Bool {
  let from_ok = match profile.valid_from {
    Some(value) =>
      match parse_iso(value) {
        Some(epoch) => at >= epoch
        None => true
      }
    None => true
  }
  let to_ok = match profile.valid_to {
    Some(value) =>
      match parse_iso(value) {
        Some(epoch) => at < epoch
        None => true
      }
    None => true
  }
  let schedule_ok = match profile.charging_schedule.start_schedule {
    Some(value) =>
      match parse_iso(value) {
        Some(start) => {
          let end = match profile.charging_schedule.duration {
            Some(span) => start + span
            None => at
          }
          at >= start && at < end
        }
        None => true
      }
    None => true
  }
  ignore(now_epoch)
  from_ok && to_ok && schedule_ok
}

///|
fn limit_at(
  profile : @v16.ChargingProfile,
  at : Int,
  now_epoch : Int,
) -> Double? {
  let start = match profile.charging_schedule.start_schedule {
    Some(value) =>
      match parse_iso(value) {
        Some(epoch) => epoch
        None => now_epoch
      }
    None =>
      match profile.valid_from {
        Some(value) =>
          match parse_iso(value) {
            Some(epoch) => epoch
            None => now_epoch
          }
        None => now_epoch
      }
  }
  let offset = at - start
  let mut limit : Double? = None
  for period in profile.charging_schedule.charging_schedule_period {
    if period.start_period <= offset {
      limit = Some(period.limit)
    }
  }
  limit
}

///|
fn unique_sorted(values : Array[Int]) -> Array[Int] {
  let result : Array[Int] = []
  for value in values {
    let mut duplicate = false
    for existing in result {
      if existing == value {
        duplicate = true
      }
    }
    if !duplicate {
      result.push(value)
    }
  }
  let mut index = 1
  while index < result.length() {
    let current = result[index]
    let mut position = index - 1
    while position >= 0 && result[position] > current {
      result[position + 1] = result[position]
      position = position - 1
    }
    result[position + 1] = current
    index = index + 1
  }
  result
}

///|
fn parse_iso(text : String) -> Int? {
  if text.length() != 20 {
    return None
  }
  let ch = fn(index : Int) -> Int? {
    match text.get_char(index) {
      Some(value) => Some(value.to_int())
      None => None
    }
  }
  let digit = fn(index : Int) -> Int? {
    match ch(index) {
      Some(code) =>
        if code >= 48 && code <= 57 {
          Some(code - 48)
        } else {
          None
        }
      None => None
    }
  }
  let two = fn(index : Int) -> Int? {
    match (digit(index), digit(index + 1)) {
      (Some(a), Some(b)) => Some(a * 10 + b)
      _ => None
    }
  }
  if ch(4) != Some(45) ||
    ch(7) != Some(45) ||
    ch(10) != Some(84) ||
    ch(13) != Some(58) ||
    ch(16) != Some(58) ||
    ch(19) != Some(90) {
    return None
  }
  match (digit(0), digit(1), digit(2), digit(3)) {
    (Some(a), Some(b), Some(c), Some(d)) => {
      let year = a * 1000 + b * 100 + c * 10 + d
      match (two(5), two(8), two(11), two(14), two(17)) {
        (Some(month), Some(day), Some(hour), Some(minute), Some(second)) =>
          Some(epoch_of(year, month, day, hour, minute, second))
        _ => None
      }
    }
    _ => None
  }
}

///|
fn epoch_of(
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Int,
) -> Int {
  days_from_civil(year, month, day) * 86400 + hour * 3600 + minute * 60 + second
}

///|
fn days_from_civil(year : Int, month : Int, day : Int) -> Int {
  let y = if month <= 2 { year - 1 } else { year }
  let era = (if y >= 0 { y } else { y - 399 }) / 400
  let yoe = y - era * 400
  let shifted = if month > 2 { month - 3 } else { month + 9 }
  let doy = (153 * shifted + 2) / 5 + day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  era * 146097 + doe - 719468
}

///|
pub fn ChargePoint::profile_count(self : ChargePoint) -> Int {
  self.profiles.length()
}

///|
/// Apply a configuration change. Unknown keys are refused with the OCPP status
/// code rather than being stored silently.
pub fn ChargePoint::set_config(
  self : ChargePoint,
  key : String,
  value : String,
) -> String {
  let writable = key == "WebSocketPingInterval" ||
    key == "MeterValueSampleInterval"
  if !writable {
    return "NotSupported"
  }
  let next : Array[(String, String)] = []
  for item in self.config {
    if item.0 == key {
      next.push((key, value))
    } else {
      next.push(item)
    }
  }
  self.config = next
  "Accepted"
}

///|
pub fn ChargePoint::config(self : ChargePoint) -> Array[(String, String)] {
  self.config
}

///|
/// Clear the authorization cache; the local list is separate and unaffected.
pub fn ChargePoint::clear_cache(self : ChargePoint) -> Unit {
  self.auth_cache = []
}

///|
pub fn ChargePoint::cache_tag(self : ChargePoint, tag : String) -> Unit {
  self.auth_cache.push(tag)
}

///|
pub fn ChargePoint::cache_size(self : ChargePoint) -> Int {
  self.auth_cache.length()
}

///|
pub fn ChargePoint::set_available(self : ChargePoint, available : Bool) -> Unit {
  if available {
    if self.connector != @schema.ConnectorStatus::Charging {
      self.connector = @schema.ConnectorStatus::Available
    }
  } else {
    self.connector = @schema.ConnectorStatus::Unavailable
  }
}

///|
pub fn ChargePoint::unlock(self : ChargePoint) -> Unit {
  if self.connector != @schema.ConnectorStatus::Available {
    self.connector = @schema.ConnectorStatus::Available
    self.transaction_16 = None
  }
}

///|
pub fn ChargePoint::reset(self : ChargePoint) -> Unit {
  self.transaction_16 = None
  self.connector = @schema.ConnectorStatus::Available
  self.booted = false
}

///|
pub fn ChargePoint::store_firmware(
  self : ChargePoint,
  location : String,
  date : String,
) -> Unit {
  self.firmware = Some((location, date))
}

///|
pub fn ChargePoint::firmware(self : ChargePoint) -> (String, String)? {
  self.firmware
}
