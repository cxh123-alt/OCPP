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

///|
test "change configuration uses key and value" {
  let request : ChangeConfiguration = {
    key: "MeterValueSampleInterval",
    value: "60",
  }
  let json = request.to_json()
  assert_eq(@schema.get_string(json, "key"), "MeterValueSampleInterval")
  assert_eq(ChangeConfiguration::from_json(json), request)
}

///|
test "get configuration can ask for specific keys" {
  let request : GetConfiguration = { keys: Some(["A", "B"]), }
  let back = GetConfiguration::from_json(request.to_json())
  assert_eq(back, request)
  let empty : GetConfiguration = { keys: None, }
  assert_eq(GetConfiguration::from_json(empty.to_json()), empty)
}

///|
test "configuration response keeps readonly and unknown keys" {
  let response : GetConfigurationResponse = {
    configuration_key: [
      { key: "A", is_readonly: false, value: Some("1"), },
      { key: "B", is_readonly: true, value: None, },
    ],
    unknown_key: Some(["C"]),
  }
  let json = response.to_json()
  assert_eq(GetConfigurationResponse::from_json(json), response)
}

///|
test "remote trigger round trip" {
  let request : RemoteTrigger = {
    requested_message: "DiagnosticsStatusNotification",
  }
  assert_eq(RemoteTrigger::from_json(request.to_json()), request)
}

///|
test "configuration actions are in the table" {
  let request = request_of(
    "ChangeConfiguration",
    @schema.obj([("key", @schema.text("K")), ("value", @schema.text("V"))]),
  )
  assert_eq(request.action(), "ChangeConfiguration")
  assert_true(!from_charge_point("ChangeConfiguration"))
}

///|
test "get diagnostics keeps the optional upload window" {
  let request : GetDiagnostics = {
    location: Some("ftp://logs.example/"),
    retries: Some(3),
    retry_interval: Some(60),
    start_time: Some("2026-11-07T00:00:00Z"),
    stop_time: None,
  }
  let back = GetDiagnostics::from_json(request.to_json())
  assert_eq(back, request)
  assert_eq(back.retries, Some(3))
}

///|
test "diagnostics and firmware notifications carry one status" {
  let diagnostics : DiagnosticsStatusNotification = { status: "Uploaded", }
  assert_eq(
    DiagnosticsStatusNotification::from_json(diagnostics.to_json()),
    diagnostics,
  )
  let firmware : FirmwareStatusNotification = { status: "Installed", }
  assert_eq(FirmwareStatusNotification::from_json(firmware.to_json()), firmware)
}

///|
test "notification directions are upstream" {
  assert_true(from_charge_point("DiagnosticsStatusNotification"))
  assert_true(from_charge_point("FirmwareStatusNotification"))
  assert_true(!from_charge_point("GetDiagnostics"))
}
