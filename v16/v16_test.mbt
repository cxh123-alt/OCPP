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

///|
test "change availability round trip" {
  let request : ChangeAvailability = { connector_id: 1, kind: "Inoperative", }
  let json = request.to_json()
  assert_eq(@schema.get_int(json, "connectorId"), 1)
  assert_eq(@schema.get_string(json, "type"), "Inoperative")
  assert_eq(ChangeAvailability::from_json(json), request)
  let response : ChangeAvailabilityResponse = { status: "Accepted", }
  assert_eq(ChangeAvailabilityResponse::from_json(response.to_json()), response)
}

///|
test "clear cache response round trip" {
  let response : ClearCacheResponse = { status: "Accepted", }
  assert_eq(ClearCacheResponse::from_json(response.to_json()), response)
}

///|
test "data transfer keeps optional fields" {
  let request : DataTransfer = {
    vendor_id: "com.example",
    message_id: Some("firmware"),
    data: Some("payload"),
  }
  assert_eq(DataTransfer::from_json(request.to_json()), request)
  let bare : DataTransfer = {
    vendor_id: "com.example",
    message_id: None,
    data: None,
  }
  assert_eq(DataTransfer::from_json(bare.to_json()), bare)
  let response : DataTransferResponse = {
    status: "Accepted",
    data: Some("ok"),
  }
  assert_eq(DataTransferResponse::from_json(response.to_json()), response)
}

///|
test "unlock connector round trip" {
  let request : UnlockConnector = { connector_id: 2, }
  assert_eq(UnlockConnector::from_json(request.to_json()), request)
  let response : UnlockConnectorResponse = { status: "Unlocked", }
  assert_eq(UnlockConnectorResponse::from_json(response.to_json()), response)
}

///|
test "core actions are classified and named" {
  let requests : Array[Request] = [
    ChangeAvailability({ connector_id: 1, kind: "Operative", }),
    ClearCache,
    DataTransfer({ vendor_id: "v", message_id: None, data: None, }),
    UnlockConnector({ connector_id: 1, }),
  ]
  assert_eq(requests[0].action(), "ChangeAvailability")
  assert_eq(requests[1].action(), "ClearCache")
  assert_eq(requests[2].action(), "DataTransfer")
  assert_eq(requests[3].action(), "UnlockConnector")
  assert_true(!from_charge_point("ChangeAvailability"))
  assert_true(!from_charge_point("ClearCache"))
  assert_true(!from_charge_point("UnlockConnector"))
  assert_true(from_charge_point("DataTransfer"))
}

///|
fn schedule() -> ChargingSchedule {
  {
    duration: Some(3600),
    start_schedule: Some("2026-11-07T06:00:00Z"),
    charging_rate_unit: "A",
    charging_schedule_period: [
      { start_period: 0, limit: 16.0, number_phases: Some(3), },
    ],
    min_charging_rate: None,
  }
}

///|
fn profile() -> ChargingProfile {
  {
    charging_profile_id: 1,
    transaction_id: None,
    stack_level: 0,
    charging_profile_purpose: "TxDefaultProfile",
    charging_profile_kind: "Absolute",
    recurrency_kind: None,
    valid_from: None,
    valid_to: None,
    charging_schedule: schedule(),
  }
}

///|
test "firmware and local list payloads round trip" {
  let update : UpdateFirmware = {
    location: "https://example.com/fw.bin",
    retrieve_date: "2026-11-07T06:00:00Z",
    retries: Some(3),
    retry_interval: Some(30),
  }
  assert_eq(UpdateFirmware::from_json(update.to_json()), update)
  let version : GetLocalListVersionResponse = { list_version: 2, }
  assert_eq(GetLocalListVersionResponse::from_json(version.to_json()), version)
  let send : SendLocalList = {
    list_version: 3,
    update_type: "Full",
    local_authorization_list: Some([{ id_tag: "TAG-9", id_tag_info: None, }]),
  }
  assert_eq(SendLocalList::from_json(send.to_json()), send)
  let sent : SendLocalListResponse = { status: "Accepted", }
  assert_eq(SendLocalListResponse::from_json(sent.to_json()), sent)
}

///|
test "reservation payloads round trip" {
  let reserve : ReserveNow = {
    connector_id: 1,
    expiry_date: "2026-11-07T07:00:00Z",
    id_tag: "TAG-9",
    reservation_id: 7,
    parent_id_tag: None,
  }
  assert_eq(ReserveNow::from_json(reserve.to_json()), reserve)
  let reserved : ReserveNowResponse = { status: "Accepted", }
  assert_eq(ReserveNowResponse::from_json(reserved.to_json()), reserved)
  let cancel : CancelReservation = { reservation_id: 7, }
  assert_eq(CancelReservation::from_json(cancel.to_json()), cancel)
  let cancelled : CancelReservationResponse = { status: "Accepted", }
  assert_eq(
    CancelReservationResponse::from_json(cancelled.to_json()),
    cancelled,
  )
}

///|
test "smart charging payloads round trip" {
  let set : SetChargingProfile = {
    connector_id: 1,
    cs_charging_profiles: profile(),
  }
  assert_eq(SetChargingProfile::from_json(set.to_json()), set)
  let set_response : SetChargingProfileResponse = { status: "Accepted", }
  assert_eq(
    SetChargingProfileResponse::from_json(set_response.to_json()),
    set_response,
  )
  let clear : ClearChargingProfile = {
    id: Some(1),
    connector_id: Some(1),
    charging_profile_purpose: None,
    stack_level: None,
  }
  assert_eq(ClearChargingProfile::from_json(clear.to_json()), clear)
  let clear_response : ClearChargingProfileResponse = { status: "Accepted", }
  assert_eq(
    ClearChargingProfileResponse::from_json(clear_response.to_json()),
    clear_response,
  )
  let get : GetCompositeSchedule = {
    connector_id: 1,
    duration: 3600,
    charging_rate_unit: Some("A"),
  }
  assert_eq(GetCompositeSchedule::from_json(get.to_json()), get)
  let got : GetCompositeScheduleResponse = {
    status: "Accepted",
    schedule: Some(schedule()),
  }
  assert_eq(GetCompositeScheduleResponse::from_json(got.to_json()), got)
}

///|
test "all 1.6J actions are addressable" {
  let names = [
    "BootNotification", "Heartbeat", "Authorize", "StartTransaction", "StopTransaction",
    "MeterValues", "StatusNotification", "RemoteStartTransaction", "RemoteStopTransaction",
    "ChangeConfiguration", "GetConfiguration", "RemoteTrigger", "GetDiagnostics",
    "DiagnosticsStatusNotification", "FirmwareStatusNotification", "Reset", "ChangeAvailability",
    "ClearCache", "DataTransfer", "UnlockConnector", "UpdateFirmware", "GetLocalListVersion",
    "SendLocalList", "ReserveNow", "CancelReservation", "SetChargingProfile", "ClearChargingProfile",
    "GetCompositeSchedule",
  ]
  assert_eq(names.length(), 28)
}

///|
test "stop transaction carries transaction data" {
  let request : StopTransaction = {
    transaction_id: 1,
    meter_stop: 1000,
    timestamp: "2026-11-07T06:00:00Z",
    reason: None,
    transaction_data: Some([
      { timestamp: "2026-11-07T05:30:00Z", sampled_value: [], },
    ]),
  }
  assert_eq(StopTransaction::from_json(request.to_json()), request)
}
