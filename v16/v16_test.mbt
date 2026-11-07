// 1.6J payload tests pin the JSON field names, because a rename is invisible
// at the type level but breaks every peer on the wire.

///|
test "boot notification uses the spec field names" {
  let request : BootNotification = {
    charge_point_model: "AC-7",
    charge_point_vendor: "MoonCharge",
    charge_point_serial_number: Some("SN-1"),
    firmware_version: None,
    iccid: None,
    imsi: None,
    meter_serial_number: None,
    meter_type: None,
  }
  let json = request.to_json()
  assert_eq(@schema.get_string(json, "chargePointModel"), "AC-7")
  assert_eq(@schema.get_string(json, "chargePointSerialNumber"), "SN-1")
  assert_eq(BootNotification::from_json(json), request)
}

///|
test "start transaction round trip" {
  let request : StartTransaction = {
    connector_id: 1,
    id_tag: "TAG-9",
    meter_start: 1000,
    reservation_id: None,
    timestamp: "2026-11-07T05:00:00Z",
  }
  assert_eq(StartTransaction::from_json(request.to_json()), request)
}

///|
test "meter values keep sample order" {
  let request : MeterValues = {
    connector_id: 1,
    transaction_id: Some(3),
    meter_value: [
      {
        timestamp: "2026-11-07T05:00:00Z",
        sampled_value: [
          {
            value: "12.5",
            measurand: Some("Energy.Active.Import.Register"),
            context: None,
            format: None,
            unit: Some("kWh"),
          },
        ],
      },
    ],
  }
  let back = MeterValues::from_json(request.to_json())
  assert_eq(back, request)
  assert_eq(back.meter_value[0].sampled_value[0].value, "12.5")
}

///|
test "status notification maps the enum to text" {
  let request : StatusNotification = {
    connector_id: 2,
    error_code: "NoError",
    status: @schema.ConnectorStatus::Charging,
    timestamp: None,
  }
  let json = request.to_json()
  assert_eq(@schema.get_string(json, "status"), "Charging")
  assert_eq(StatusNotification::from_json(json), request)
}

///|
test "unknown action is reported" {
  let caught = try {
    ignore(request_of("ChargeNow", @schema.obj([])))
    false
  } catch {
    @schema.SchemaError::UnknownCode(name) => name == "ChargeNow"
    _ => false
  }
  assert_true(caught)
}

///|
test "direction table separates the two sides" {
  assert_true(from_charge_point("BootNotification"))
  assert_true(from_charge_point("MeterValues"))
  assert_true(!from_charge_point("RemoteStartTransaction"))
  assert_true(!from_charge_point("Reset"))
}

///|
test "request enum exposes its action name" {
  let request = Request::Heartbeat
  assert_eq(request.action(), "Heartbeat")
  assert_true(request.to_json() is Json::Object(_))
}
