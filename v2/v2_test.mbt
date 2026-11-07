// 2.0.1 payload tests. The nesting differences from 1.6 are the point: an
// id token is an object here, and a transaction is identified by a string.

///|
test "authorize nests the token object" {
  let request = Request::Authorize({ value: "TAG-1", kind: Central, })
  let json = request.to_json()
  assert_eq(
    @schema.get_string(@schema.get_object(json, "idToken"), "idToken"),
    "TAG-1",
  )
  let back = request_of("Authorize", json)
  assert_eq(back, request)
}

///|
test "boot notification carries a station object" {
  let request : BootNotification = {
    reason: PowerUp,
    station: {
      model: "DC-120",
      vendor: "MoonCharge",
      serial_number: Some("SN-9"),
      firmware_version: Some("1.2.3"),
    },
  }
  let json = request.to_json()
  assert_eq(@schema.get_string(json, "reason"), "PowerUp")
  assert_eq(BootNotification::from_json(json), request)
}

///|
test "transaction event survives nested meter values" {
  let event : TransactionEvent = {
    event_type: @schema.TransactionEventKind::Started,
    timestamp: "2026-11-07T05:00:00Z",
    trigger_reason: "CablePluggedIn",
    seq_no: 1,
    transaction_info: {
      transaction_id: "TX-1",
      charging_state: None,
      stopped_reason: None,
    },
    id_token: Some({ value: "TAG-1", kind: Local, }),
    evse_id: Some(1),
    meter_value: Some([
      {
        timestamp: "2026-11-07T05:00:00Z",
        sampled_value: [
          {
            value: "0",
            measurand: Some("Energy.Active.Import.Register"),
            context: None,
            phase: None,
          },
        ],
      },
    ]),
  }
  let back = TransactionEvent::from_json(event.to_json())
  assert_eq(back, event)
  assert_eq(back.seq_no, 1)
}

///|
test "status notification uses connectorStatus" {
  let note : StatusNotification = {
    timestamp: "2026-11-07T05:00:00Z",
    connector_status: @schema.ConnectorStatus::Available,
    evse_id: 1,
    connector_id: 1,
  }
  let json = note.to_json()
  assert_eq(@schema.get_string(json, "connectorStatus"), "Available")
  assert_eq(StatusNotification::from_json(json), note)
}

///|
test "unknown 2.0.1 action is reported" {
  let caught = try {
    ignore(request_of("MeterValues2", @schema.obj([])))
    false
  } catch {
    @schema.SchemaError::UnknownCode(name) => name == "MeterValues2"
    _ => false
  }
  assert_true(caught)
}

///|
test "2.0.1 direction table" {
  assert_true(from_charge_point("TransactionEvent"))
  assert_true(!from_charge_point("RequestStartTransaction"))
  assert_true(!from_charge_point("Reset"))
}

test "get variables nests component and variable" {
  let request : GetVariables = {
    items: [
      {
        component: { name: "EVSE", instance: Some("1") },
        variable: { name: "AvailabilityState", instance: None },
        attribute_type: Some("Actual"),
      },
    ],
  }
  let json = request.to_json()
  let back = GetVariables::from_json(json)
  assert_eq(back, request)
  assert_eq(back.items[0].variable.name, "AvailabilityState")
}

test "set variables carries values per variable" {
  let request : SetVariables = {
    items: [
      {
        attribute_type: None,
        attribute_value: "60",
        component: { name: "OCPPCommCtrlr", instance: None },
        variable: { name: "HeartbeatInterval", instance: None },
      },
    ],
  }
  let back = SetVariables::from_json(request.to_json())
  assert_eq(back, request)
  assert_eq(back.items[0].attribute_value, "60")
}

test "variable actions are in the table" {
  let request = request_of("GetVariables", @schema.obj([("getVariableData", Json::array([]))]))
  assert_eq(request.action(), "GetVariables")
  assert_true(!from_charge_point("GetVariables"))
}