// Schema tests pin the small conventions that both protocol versions depend
// on: optional keys, fixed-width timestamps and the exact status strings.

test "object round trip with optional keys" {
  let payload = obj([
    ("model", text("AC-7")),
    ("vendor", text("MoonCharge")),
  ])
  assert_eq(get_string(payload, "model"), "AC-7")
  assert_eq(opt_string(payload, "serialNumber"), None)
  assert_eq(opt_string(payload, "vendor"), Some("MoonCharge"))
}

test "wrong field type is named" {
  let payload = obj([("connectorId", text("one"))])
  let caught = try {
    ignore(get_int(payload, "connectorId"))
    false
  } catch {
    SchemaError::WrongType(key) => key == "connectorId"
    _ => false
  }
  assert_true(caught)
}

test "missing field is named" {
  let payload = obj([])
  let caught = try {
    ignore(get_string(payload, "idTag"))
    false
  } catch {
    SchemaError::MissingField(key) => key == "idTag"
    _ => false
  }
  assert_true(caught)
}

test "timestamp is zero padded" {
  let time : ClockTime = {
    year: 2026,
    month: 11,
    day: 7,
    hour: 5,
    minute: 0,
    second: 9,
  }
  assert_eq(time.iso(), "2026-11-07T05:00:09Z")
}

test "advancing a clock wraps within the day" {
  let time : ClockTime = {
    year: 2026,
    month: 11,
    day: 7,
    hour: 23,
    minute: 59,
    second: 50,
  }
  assert_eq(time.advance(20).iso(), "2026-11-07T00:00:10Z")
}

test "charging station keeps optional identity" {
  let station : ChargingStation = {
    model: "AC-7",
    vendor: "MoonCharge",
    serial_number: Some("SN-1"),
    firmware_version: None,
  }
  let back = ChargingStation::from_json(station.to_json())
  assert_eq(back, station)
}

test "status codes survive a trip through text" {
  assert_eq(registration_status("Pending"), Some(RegistrationStatus::Pending))
  assert_eq(RegistrationStatus::Pending.code(), "Pending")
  assert_eq(connector_status("SuspendedEVSE"), Some(ConnectorStatus::SuspendedEVSE))
  assert_eq(ConnectorStatus::SuspendedEVSE.code(), "SuspendedEVSE")
  assert_eq(reset_kind("Hard"), Some(ResetKind::Hard))
  assert_eq(registration_status("Maybe"), None)
}
