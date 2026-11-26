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
  mut voltage : Double
  mut reservations : Array[(Int, String, Int)]
  mut profiles : Array[(Int, @v16.ChargingProfile)]
  mut config : Array[(String, String)]
  readonly_keys : Array[String]
  mut auth_cache : Array[String]
  mut firmware : (String, String)?
  mut firmware_retries : Int?
  mut firmware_retry_interval : Int?
  mut diagnostics_location : String?
  mut diagnostics_retries : Int?
  mut diagnostics_start : String?
  mut diagnostics_stop : String?
  mut firmware_status : String
  mut diagnostics_status : String
  mut vendors : Array[String]
  mut message_routes : Array[(String, String)]
  mut last_trigger : String?
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
    voltage: 230.0,
    reservations: [],
    profiles: [],
    readonly_keys: ["WebSocketPingInterval"],
    config: [
      ("WebSocketPingInterval", "60"),
      ("MeterValueSampleInterval", "300"),
    ],
    auth_cache: [],
    firmware: None,
    firmware_retries: None,
    firmware_retry_interval: None,
    diagnostics_location: None,
    diagnostics_retries: None,
    diagnostics_start: None,
    diagnostics_stop: None,
    firmware_status: "Idle",
    diagnostics_status: "Idle",
    vendors: [],
    message_routes: [],
    last_trigger: None,
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
/// Apply a local list update. `Full` replaces the list, `Differential` upserts
/// or removes entries, and a differential version that is not newer than the
/// stored one is refused with VersionMismatch.
pub fn ChargePoint::apply_local_list(
  self : ChargePoint,
  version : Int,
  entries : Array[(String, Bool)],
  update_type : String,
) -> String {
  if update_type != "Full" && update_type != "Differential" {
    return "NotSupported"
  }
  if update_type == "Differential" && version <= self.local_list_version {
    return "VersionMismatch"
  }
  if update_type == "Full" {
    let next : Array[String] = []
    for entry in entries {
      if entry.1 {
        next.push(entry.0)
      }
    }
    self.local_list = next
  } else {
    for entry in entries {
      if entry.1 {
        let mut present = false
        for tag in self.local_list {
          if tag == entry.0 {
            present = true
          }
        }
        if !present {
          self.local_list.push(entry.0)
        }
      } else {
        let kept : Array[String] = []
        for tag in self.local_list {
          if tag != entry.0 {
            kept.push(tag)
          }
        }
        self.local_list = kept
      }
    }
  }
  self.local_list_version = version
  "Accepted"
}

///|
pub fn ChargePoint::set_voltage(self : ChargePoint, voltage : Double) -> Unit {
  self.voltage = voltage
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
/// Release reservations whose expiry is in the past. Hosts can call this on a
/// timer; ReserveNow also calls it before accepting a new reservation.
pub fn ChargePoint::release_expired(self : ChargePoint, now : String) -> Int {
  let kept : Array[(Int, String, Int)] = []
  let mut removed = 0
  for item in self.reservations {
    if item.1 <= now {
      removed = removed + 1
    } else {
      kept.push(item)
    }
  }
  self.reservations = kept
  removed
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
pub fn ChargePoint::composite_schedule_with_unit(
  self : ChargePoint,
  connector_id : Int,
  now : String,
  duration : Int,
  requested_unit : String?,
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
    let station_current = match station {
      Some(profile) => current_at(profile, at, now_epoch, self.voltage)
      None => None
    }
    let tx_current = match tx {
      Some(profile) => current_at(profile, at, now_epoch, self.voltage)
      None => None
    }
    let effective = match (tx_current, station_current) {
      (Some(tx_value), Some(station_value)) =>
        Some(if tx_value < station_value { tx_value } else { station_value })
      (Some(value), None) => Some(value)
      (None, Some(value)) => Some(value)
      (None, None) => None
    }
    match effective {
      Some(current_value) => {
        let out_unit = match requested_unit {
          Some(unit) => unit
          None =>
            match tx {
              Some(profile) => profile.charging_schedule.charging_rate_unit
              None =>
                match station {
                  Some(profile) => profile.charging_schedule.charging_rate_unit
                  None => "A"
                }
            }
        }
        let out_phases = match tx {
          Some(profile) => phases_at(profile, at, now_epoch)
          None =>
            match station {
              Some(profile) => phases_at(profile, at, now_epoch)
              None => 3
            }
        }
        let minimum = match tx {
          Some(profile) => min_current_at(profile, at, now_epoch, self.voltage)
          None =>
            match station {
              Some(profile) =>
                min_current_at(profile, at, now_epoch, self.voltage)
              None => None
            }
        }
        let paused = match minimum {
          Some(value) => current_value < value
          None => false
        }
        let limit = if paused {
          0.0
        } else if out_unit == "A" {
          current_value
        } else {
          current_value * self.voltage * out_phases.to_double()
        }
        unit = out_unit
        let duplicate = if periods.length() > 0 {
          periods[periods.length() - 1].limit == limit
        } else {
          false
        }
        if !duplicate {
          periods.push({
            start_period: offset,
            limit,
            number_phases: Some(out_phases),
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
pub fn ChargePoint::composite_schedule(
  self : ChargePoint,
  connector_id : Int,
  now : String,
  duration : Int,
) -> @v16.ChargingSchedule? {
  self.composite_schedule_with_unit(connector_id, now, duration, None)
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
    let transaction_ok = if purpose == "TxProfile" {
      match item.1.transaction_id {
        Some(id) =>
          match self.transaction_16 {
            Some(current) => current == id
            None => false
          }
        None => true
      }
    } else {
      true
    }
    if item.0 == connector_id &&
      item.1.charging_profile_purpose == purpose &&
      transaction_ok &&
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

///|
/// Offset inside the schedule at `at`, or None when the schedule does not cover
/// that instant. Recurring profiles repeat daily or weekly from startSchedule.
fn schedule_offset(
  profile : @v16.ChargingProfile,
  at : Int,
  now_epoch : Int,
) -> Int? {
  let explicit_start = match profile.charging_schedule.start_schedule {
    Some(value) => parse_iso(value)
    None => None
  }
  let start = match explicit_start {
    Some(value) => value
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
  if at < start {
    return None
  }
  let elapsed = at - start
  match explicit_start {
    None => Some(elapsed)
    Some(_) =>
      if profile.charging_profile_kind == "Recurring" {
        let span = match profile.recurrency_kind {
          Some("Weekly") => 604800
          _ => 86400
        }
        let cycle = elapsed % span
        match profile.charging_schedule.duration {
          Some(duration) => if cycle < duration { Some(cycle) } else { None }
          None => Some(cycle)
        }
      } else {
        match profile.charging_schedule.duration {
          Some(duration) =>
            if elapsed < duration {
              Some(elapsed)
            } else {
              None
            }
          None => Some(elapsed)
        }
      }
  }
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
  from_ok && to_ok && schedule_offset(profile, at, now_epoch) is Some(_)
}

///|
fn current_at(
  profile : @v16.ChargingProfile,
  at : Int,
  now_epoch : Int,
  voltage : Double,
) -> Double? {
  match limit_at(profile, at, now_epoch) {
    Some(value) =>
      if profile.charging_schedule.charging_rate_unit == "A" {
        Some(value)
      } else {
        Some(value / (voltage * phases_at(profile, at, now_epoch).to_double()))
      }
    None => None
  }
}

///|
fn min_current_at(
  profile : @v16.ChargingProfile,
  at : Int,
  now_epoch : Int,
  voltage : Double,
) -> Double? {
  match profile.charging_schedule.min_charging_rate {
    Some(value) =>
      if profile.charging_schedule.charging_rate_unit == "A" {
        Some(value)
      } else {
        Some(value / (voltage * phases_at(profile, at, now_epoch).to_double()))
      }
    None => None
  }
}

///|
fn phases_at(profile : @v16.ChargingProfile, at : Int, now_epoch : Int) -> Int {
  let offset = match schedule_offset(profile, at, now_epoch) {
    Some(value) => value
    None => 0
  }
  let mut phases = 3
  for period in profile.charging_schedule.charging_schedule_period {
    if period.start_period <= offset {
      phases = match period.number_phases {
        Some(value) => value
        None => 3
      }
    }
  }
  phases
}

///|
fn limit_at(
  profile : @v16.ChargingProfile,
  at : Int,
  now_epoch : Int,
) -> Double? {
  let offset = match schedule_offset(profile, at, now_epoch) {
    Some(value) => value
    None => return None
  }
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
  let length = text.length()
  if length != 20 && length != 25 {
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
    ch(16) != Some(58) {
    return None
  }
  let zone_ok = if length == 20 {
    ch(19) == Some(90)
  } else {
    let sign_ok = ch(19) == Some(43) || ch(19) == Some(45)
    sign_ok && ch(22) == Some(58)
  }
  if !zone_ok {
    return None
  }
  match (digit(0), digit(1), digit(2), digit(3)) {
    (Some(a), Some(b), Some(c), Some(d)) => {
      let year = a * 1000 + b * 100 + c * 10 + d
      match (two(5), two(8), two(11), two(14), two(17)) {
        (Some(month), Some(day), Some(hour), Some(minute), Some(second)) => {
          let base = epoch_of(year, month, day, hour, minute, second)
          if length == 20 {
            Some(base)
          } else {
            match (digit(20), digit(21), digit(23), digit(24)) {
              (Some(h1), Some(h2), Some(m1), Some(m2)) => {
                let offset = (h1 * 10 + h2) * 3600 + (m1 * 10 + m2) * 60
                let sign = if ch(19) == Some(43) { 1 } else { -1 }
                Some(base - sign * offset)
              }
              _ => None
            }
          }
        }
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
  for item in self.readonly_keys {
    if item == key {
      return "Rejected"
    }
  }
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
  retries : Int?,
  retry_interval : Int?,
) -> Unit {
  self.firmware = Some((location, date))
  self.firmware_retries = retries
  self.firmware_retry_interval = retry_interval
}

///|
pub fn ChargePoint::store_diagnostics(
  self : ChargePoint,
  location : String?,
  retries : Int?,
  start : String?,
  stop : String?,
) -> Unit {
  self.diagnostics_location = location
  self.diagnostics_retries = retries
  self.diagnostics_start = start
  self.diagnostics_stop = stop
}

///|
pub fn ChargePoint::firmware_retries(self : ChargePoint) -> Int? {
  self.firmware_retries
}

///|
pub fn ChargePoint::diagnostics_location(self : ChargePoint) -> String? {
  self.diagnostics_location
}

///|
pub fn ChargePoint::firmware(self : ChargePoint) -> (String, String)? {
  self.firmware
}

///|
pub fn ChargePoint::register_vendor(
  self : ChargePoint,
  vendor : String,
) -> Unit {
  self.vendors.push(vendor)
}

///|
/// DataTransfer is vendor-specific: only registered vendors get Accepted.
pub fn ChargePoint::data_transfer(
  self : ChargePoint,
  vendor : String,
  message_id : String?,
) -> String {
  let mut known = false
  for item in self.vendors {
    if item == vendor {
      known = true
    }
  }
  if !known {
    return "UnknownVendorId"
  }
  match message_id {
    None => "Accepted"
    Some(message) => {
      let mut routed = false
      for item in self.message_routes {
        if item.0 == vendor && item.1 == message {
          routed = true
        }
      }
      if routed {
        "Accepted"
      } else {
        "UnknownMessageId"
      }
    }
  }
}

///|
pub fn ChargePoint::register_message(
  self : ChargePoint,
  vendor : String,
  message : String,
) -> Unit {
  self.message_routes.push((vendor, message))
}

///|
pub fn ChargePoint::set_firmware_status(
  self : ChargePoint,
  status : String,
) -> Unit {
  self.firmware_status = status
}

///|
pub fn ChargePoint::firmware_status(self : ChargePoint) -> String {
  self.firmware_status
}

///|
pub fn ChargePoint::set_diagnostics_status(
  self : ChargePoint,
  status : String,
) -> Unit {
  self.diagnostics_status = status
}

///|
pub fn ChargePoint::diagnostics_status(self : ChargePoint) -> String {
  self.diagnostics_status
}

///|
pub fn ChargePoint::trigger(self : ChargePoint, message : String) -> Unit {
  self.last_trigger = Some(message)
}

///|
pub fn ChargePoint::last_trigger(self : ChargePoint) -> String? {
  self.last_trigger
}

///|
pub fn ChargePoint::is_readonly(self : ChargePoint, key : String) -> Bool {
  let mut found = false
  for item in self.readonly_keys {
    if item == key {
      found = true
    }
  }
  found
}
