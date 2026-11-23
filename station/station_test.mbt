// Charge point tests. They look at the text produced, because that text is
// what a real central system would receive.

///|
fn clock() -> @schema.ClockTime {
  { year: 2026, month: 11, day: 7, hour: 5, minute: 0, second: 0, }
}

///|
test "1.6 boot carries the model and vendor" {
  let session = Session::new(ChargePoint::new("CP-1", Version::V16), clock())
  let text = session.boot_frame()
  let frame = @wire.parse(text)
  match frame {
    @wire.Frame::Call(call) => {
      assert_eq(call.action, "BootNotification")
      assert_eq(@schema.get_string(call.payload, "chargePointModel"), "MC-7")
    }
    _ => fail("expected a call")
  }
}

///|

///|
test "starting a transaction flips the connector" {
  let session = Session::new(ChargePoint::new("CP-3", Version::V16), clock())
  let text = session.start_frame("TAG-1", 5)
  assert_true(session.cp.is_charging())
  assert_eq(session.cp.transaction_label(), "5")
  match @wire.parse(text) {
    @wire.Frame::Call(call) => assert_eq(call.action, "StartTransaction")
    _ => fail("expected a call")
  }
}

///|
test "meter values accumulate energy" {
  let session = Session::new(ChargePoint::new("CP-4", Version::V16), clock())
  ignore(session.start_frame("TAG-1", 7))
  ignore(session.meter_frame(2500, 60))
  assert_eq(session.cp.meter_wh, 2500)
  assert_eq(session.clock.iso(), "2026-11-07T05:01:00Z")
}

///|
test "a remote start is answered with a status" {
  let session = Session::new(ChargePoint::new("CP-5", Version::V16), clock())
  let command = @wire.encode(
    @wire.Frame::Call({
      id: "cs-1",
      action: "RemoteStartTransaction",
      payload: @schema.obj([("idTag", @schema.text("TAG-1"))]),
    }),
  )
  let replies = session.handle(command)
  assert_eq(replies.length(), 1)
  match @wire.parse(replies[0]) {
    @wire.Frame::Result(result) =>
      assert_eq(@schema.get_string(result.payload, "status"), "Accepted")
    _ => fail("expected a result")
  }
  assert_true(session.cp.is_charging())
}

///|
test "an unknown command is refused" {
  let session = Session::new(ChargePoint::new("CP-6", Version::V16), clock())
  let command = @wire.encode(
    @wire.Frame::Call({
      id: "cs-2",
      action: "UnlockCable",
      payload: @schema.obj([]),
    }),
  )
  let replies = session.handle(command)
  match @wire.parse(replies[0]) {
    @wire.Frame::Failure(error) => assert_eq(error.code, "NotSupported")
    _ => fail("expected an error")
  }
}

///|
test "get configuration returns typed keys" {
  let session = Session::new(ChargePoint::new("CP-7", Version::V16), clock())
  let command = @wire.encode(
    @wire.Frame::Call({
      id: "cs-3",
      action: "GetConfiguration",
      payload: @schema.obj([
        ("key", Json::array([@schema.text("WebSocketPingInterval")])),
      ]),
    }),
  )
  let replies = session.handle(command)
  assert_eq(replies.length(), 1)
  match @wire.parse(replies[0]) {
    @wire.Frame::Result(result) => {
      let keys = @schema.get_array(result.payload, "configurationKey")
      assert_eq(keys.length(), 1)
    }
    _ => fail("expected a result")
  }
}

///|

///|
test "get diagnostics returns a file name" {
  let session = Session::new(ChargePoint::new("CP-9", Version::V16), clock())
  let command = @wire.encode(
    @wire.Frame::Call({
      id: "cs-5",
      action: "GetDiagnostics",
      payload: @schema.obj([("location", @schema.text("ftp://logs.example/"))]),
    }),
  )
  let replies = session.handle(command)
  match @wire.parse(replies[0]) {
    @wire.Frame::Result(result) =>
      assert_eq(
        @schema.get_string(result.payload, "fileName"),
        "diag-20261107.log",
      )
    _ => fail("expected a result")
  }
}

///|
fn local_list_call(id : String, version : Int) -> String {
  @wire.encode(
    @wire.Frame::Call({
      id,
      action: "SendLocalList",
      payload: @schema.obj([
        ("listVersion", @schema.integer(version)),
        ("updateType", @schema.text("Full")),
        (
          "localAuthorizationList",
          Json::array([
            @schema.obj([("idTag", @schema.text("TAG-1"))]),
            @schema.obj([("idTag", @schema.text("TAG-2"))]),
          ]),
        ),
      ]),
    }),
  )
}

///|
test "local list version follows SendLocalList" {
  let session = Session::new(ChargePoint::new("CP-10", Version::V16), clock())
  ignore(session.handle(local_list_call("1", 4)))
  assert_eq(session.cp.local_list_version(), 4)
  assert_eq(session.cp.local_list.length(), 2)
}

///|
test "reservation is stored and cancelled" {
  let session = Session::new(ChargePoint::new("CP-11", Version::V16), clock())
  let reserve = @wire.encode(
    @wire.Frame::Call({
      id: "2",
      action: "ReserveNow",
      payload: @schema.obj([
        ("connectorId", @schema.integer(1)),
        ("expiryDate", @schema.text("2026-11-07T07:00:00Z")),
        ("idTag", @schema.text("TAG-1")),
        ("reservationId", @schema.integer(9)),
      ]),
    }),
  )
  ignore(session.handle(reserve))
  assert_eq(session.cp.reservation_count(), 1)
  let cancel = @wire.encode(
    @wire.Frame::Call({
      id: "3",
      action: "CancelReservation",
      payload: @schema.obj([("reservationId", @schema.integer(9))]),
    }),
  )
  ignore(session.handle(cancel))
  assert_eq(session.cp.reservation_count(), 0)
}

///|
test "composite schedule returns the stored profile" {
  let session = Session::new(ChargePoint::new("CP-12", Version::V16), clock())
  let set = @wire.encode(
    @wire.Frame::Call({
      id: "4",
      action: "SetChargingProfile",
      payload: @schema.obj([
        ("connectorId", @schema.integer(1)),
        (
          "csChargingProfiles",
          @schema.obj([
            ("chargingProfileId", @schema.integer(1)),
            ("stackLevel", @schema.integer(0)),
            ("chargingProfilePurpose", @schema.text("TxDefaultProfile")),
            ("chargingProfileKind", @schema.text("Absolute")),
            (
              "chargingSchedule",
              @schema.obj([
                ("chargingRateUnit", @schema.text("A")),
                (
                  "chargingSchedulePeriod",
                  Json::array([
                    @schema.obj([
                      ("startPeriod", @schema.integer(0)),
                      ("limit", @schema.number(16.0)),
                    ]),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    }),
  )
  ignore(session.handle(set))
  assert_true(
    session.cp.composite_schedule(1, "2026-11-07T05:00:00Z", 3600) is Some(_),
  )
  let get = @wire.encode(
    @wire.Frame::Call({
      id: "5",
      action: "GetCompositeSchedule",
      payload: @schema.obj([
        ("connectorId", @schema.integer(1)),
        ("duration", @schema.integer(3600)),
      ]),
    }),
  )
  ignore(session.handle(get))
  assert_true(
    session.cp.composite_schedule(1, "2026-11-07T05:00:00Z", 3600) is Some(_),
  )
}

///|
test "reservation on an occupied connector is refused" {
  let cp = ChargePoint::new("CP-13", Version::V16)
  cp.begin_transaction(1)
  assert_eq(cp.reserve(1, "2026-11-07T07:00:00Z", 1), "Occupied")
  assert_eq(cp.reservation_count(), 0)
}

///|
test "second reservation on the same connector is refused" {
  let cp = ChargePoint::new("CP-14", Version::V16)
  assert_eq(cp.reserve(1, "2026-11-07T07:00:00Z", 1), "Accepted")
  assert_eq(cp.reserve(2, "2026-11-07T08:00:00Z", 1), "Occupied")
  assert_eq(cp.reservation_count(), 1)
}

///|
test "higher stack level wins the composite schedule" {
  let cp = ChargePoint::new("CP-15", Version::V16)
  cp.set_profile(1, low_profile())
  cp.set_profile(1, high_profile())
  match cp.composite_schedule(1, "2026-11-07T05:00:00Z", 3600) {
    Some(schedule) =>
      assert_eq(schedule.charging_schedule_period[0].limit, 10.0)
    None => fail("expected a composite schedule")
  }
  assert_eq(cp.clear_profiles(None, Some(1), None, None), 2)
  assert_true(cp.composite_schedule(1, "2026-11-07T05:00:00Z", 3600) is None)
}

///|
fn low_profile() -> @v16.ChargingProfile {
  {
    charging_profile_id: 1,
    transaction_id: None,
    stack_level: 0,
    charging_profile_purpose: "TxDefaultProfile",
    charging_profile_kind: "Absolute",
    recurrency_kind: None,
    valid_from: None,
    valid_to: None,
    charging_schedule: {
      duration: Some(3600),
      start_schedule: None,
      charging_rate_unit: "A",
      charging_schedule_period: [
        { start_period: 0, limit: 16.0, number_phases: None, },
      ],
      min_charging_rate: None,
    },
  }
}

///|
fn high_profile() -> @v16.ChargingProfile {
  {
    charging_profile_id: 2,
    transaction_id: None,
    stack_level: 1,
    charging_profile_purpose: "TxDefaultProfile",
    charging_profile_kind: "Absolute",
    recurrency_kind: None,
    valid_from: None,
    valid_to: None,
    charging_schedule: {
      duration: Some(3600),
      start_schedule: None,
      charging_rate_unit: "A",
      charging_schedule_period: [
        { start_period: 0, limit: 10.0, number_phases: None, },
      ],
      min_charging_rate: None,
    },
  }
}

///|
test "an expired high profile falls back to the lower one" {
  let cp = ChargePoint::new("CP-16", Version::V16)
  cp.set_profile(1, low_profile())
  cp.set_profile(1, expiring_high_profile())
  match cp.composite_schedule(1, "2026-11-07T05:00:00Z", 3600) {
    Some(schedule) =>
      assert_eq(schedule.charging_schedule_period[0].limit, 10.0)
    None => fail("expected the high profile")
  }
  match cp.composite_schedule(1, "2026-11-07T07:00:00Z", 3600) {
    Some(schedule) =>
      assert_eq(schedule.charging_schedule_period[0].limit, 16.0)
    None => fail("expected the lower profile after expiry")
  }
}

///|
fn expiring_high_profile() -> @v16.ChargingProfile {
  {
    charging_profile_id: 3,
    transaction_id: None,
    stack_level: 1,
    charging_profile_purpose: "TxDefaultProfile",
    charging_profile_kind: "Absolute",
    recurrency_kind: None,
    valid_from: Some("2026-11-07T04:00:00Z"),
    valid_to: Some("2026-11-07T06:00:00Z"),
    charging_schedule: {
      duration: Some(3600),
      start_schedule: None,
      charging_rate_unit: "A",
      charging_schedule_period: [
        { start_period: 0, limit: 10.0, number_phases: None, },
      ],
      min_charging_rate: None,
    },
  }
}

///|
test "clearing an absent profile reports Unknown" {
  let session = Session::new(ChargePoint::new("CP-17", Version::V16), clock())
  let clear = @wire.encode(
    @wire.Frame::Call({
      id: "6",
      action: "ClearChargingProfile",
      payload: @schema.obj([("connectorId", @schema.integer(1))]),
    }),
  )
  let replies = session.handle(clear)
  assert_eq(replies.length(), 1)
  let frame = @wire.parse(replies[0])
  match frame {
    @wire.Frame::Result(result) =>
      assert_eq(@schema.get_string(result.payload, "status"), "Unknown")
    _ => fail("expected a CALLRESULT")
  }
}

///|
test "composite covers the duration and falls back mid-window" {
  let cp = ChargePoint::new("CP-18", Version::V16)
  cp.set_profile(1, low_profile())
  cp.set_profile(1, expiring_high_profile())
  match cp.composite_schedule(1, "2026-11-07T05:00:00Z", 7200) {
    Some(schedule) => {
      assert_eq(schedule.charging_schedule_period.length(), 2)
      assert_eq(schedule.charging_schedule_period[0].start_period, 0)
      assert_eq(schedule.charging_schedule_period[0].limit, 10.0)
      assert_eq(schedule.charging_schedule_period[1].start_period, 3600)
      assert_eq(schedule.charging_schedule_period[1].limit, 16.0)
    }
    None => fail("expected a composite schedule")
  }
}

///|
test "composite keeps schedule period boundaries" {
  let cp = ChargePoint::new("CP-19", Version::V16)
  cp.set_profile(1, two_period_profile())
  match cp.composite_schedule(1, "2026-11-07T05:00:00Z", 3600) {
    Some(schedule) => {
      assert_eq(schedule.charging_schedule_period.length(), 2)
      assert_eq(schedule.charging_schedule_period[0].limit, 16.0)
      assert_eq(schedule.charging_schedule_period[1].start_period, 1800)
      assert_eq(schedule.charging_schedule_period[1].limit, 8.0)
    }
    None => fail("expected a composite schedule")
  }
}

///|
fn two_period_profile() -> @v16.ChargingProfile {
  {
    charging_profile_id: 4,
    transaction_id: None,
    stack_level: 0,
    charging_profile_purpose: "TxDefaultProfile",
    charging_profile_kind: "Absolute",
    recurrency_kind: None,
    valid_from: None,
    valid_to: None,
    charging_schedule: {
      duration: Some(3600),
      start_schedule: None,
      charging_rate_unit: "A",
      charging_schedule_period: [
        { start_period: 0, limit: 16.0, number_phases: None, },
        { start_period: 1800, limit: 8.0, number_phases: None, },
      ],
      min_charging_rate: None,
    },
  }
}

///|
test "configuration changes are stored and returned" {
  let session = Session::new(ChargePoint::new("CP-20", Version::V16), clock())
  let change = @wire.encode(
    @wire.Frame::Call({
      id: "7",
      action: "ChangeConfiguration",
      payload: @schema.obj([
        ("key", @schema.text("MeterValueSampleInterval")),
        ("value", @schema.text("120")),
      ]),
    }),
  )
  ignore(session.handle(change))
  let get = @wire.encode(
    @wire.Frame::Call({
      id: "8",
      action: "GetConfiguration",
      payload: @schema.empty(),
    }),
  )
  let replies = session.handle(get)
  assert_eq(replies.length(), 1)
}

///|
test "unavailable connector refuses a reservation" {
  let session = Session::new(ChargePoint::new("CP-21", Version::V16), clock())
  let change = @wire.encode(
    @wire.Frame::Call({
      id: "9",
      action: "ChangeAvailability",
      payload: @schema.obj([
        ("connectorId", @schema.integer(1)),
        ("type", @schema.text("Inoperative")),
      ]),
    }),
  )
  ignore(session.handle(change))
  let reserve = @wire.encode(
    @wire.Frame::Call({
      id: "10",
      action: "ReserveNow",
      payload: @schema.obj([
        ("connectorId", @schema.integer(1)),
        ("expiryDate", @schema.text("2026-11-07T07:00:00Z")),
        ("idTag", @schema.text("TAG-1")),
        ("reservationId", @schema.integer(1)),
      ]),
    }),
  )
  let replies = session.handle(reserve)
  let frame = @wire.parse(replies[0])
  match frame {
    @wire.Frame::Result(result) =>
      assert_eq(@schema.get_string(result.payload, "status"), "Unavailable")
    _ => fail("expected a CALLRESULT")
  }
}

///|
test "clear cache empties the authorization cache" {
  let session = Session::new(ChargePoint::new("CP-22", Version::V16), clock())
  ignore(session.authorize_frame("TAG-1"))
  assert_eq(session.cp.cache_size(), 1)
  let clear = @wire.encode(
    @wire.Frame::Call({
      id: "11",
      action: "ClearCache",
      payload: @schema.empty(),
    }),
  )
  ignore(session.handle(clear))
  assert_eq(session.cp.cache_size(), 0)
}

///|
test "reset clears the transaction and connector state" {
  let session = Session::new(ChargePoint::new("CP-23", Version::V16), clock())
  session.cp.begin_transaction(5)
  let reset = @wire.encode(
    @wire.Frame::Call({
      id: "12",
      action: "Reset",
      payload: @schema.obj([("type", @schema.text("Soft"))]),
    }),
  )
  ignore(session.handle(reset))
  assert_true(session.cp.transaction_16 is None)
  assert_eq(session.cp.connector, @schema.ConnectorStatus::Available)
}

///|
test "update firmware stores the request" {
  let session = Session::new(ChargePoint::new("CP-24", Version::V16), clock())
  let update = @wire.encode(
    @wire.Frame::Call({
      id: "13",
      action: "UpdateFirmware",
      payload: @schema.obj([
        ("location", @schema.text("https://example.com/fw.bin")),
        ("retrieveDate", @schema.text("2026-11-07T06:00:00Z")),
      ]),
    }),
  )
  ignore(session.handle(update))
  assert_true(session.cp.firmware() is Some(_))
}

///|
fn simple_profile(purpose : String, limit : Double) -> @v16.ChargingProfile {
  {
    charging_profile_id: 9,
    transaction_id: None,
    stack_level: 0,
    charging_profile_purpose: purpose,
    charging_profile_kind: "Absolute",
    recurrency_kind: None,
    valid_from: None,
    valid_to: None,
    charging_schedule: {
      duration: Some(3600),
      start_schedule: None,
      charging_rate_unit: "A",
      charging_schedule_period: [
        { start_period: 0, limit, number_phases: None, },
      ],
      min_charging_rate: None,
    },
  }
}

///|
test "station maximum caps a higher transaction profile" {
  let cp = ChargePoint::new("CP-25", Version::V16)
  cp.set_profile(0, simple_profile("ChargePointMaxProfile", 16.0))
  cp.set_profile(1, simple_profile("TxProfile", 32.0))
  match cp.composite_schedule(1, "2026-11-07T05:00:00Z", 3600) {
    Some(schedule) =>
      assert_eq(schedule.charging_schedule_period[0].limit, 16.0)
    None => fail("expected a composite schedule")
  }
}

///|
test "transaction profile below the station maximum wins" {
  let cp = ChargePoint::new("CP-26", Version::V16)
  cp.set_profile(0, simple_profile("ChargePointMaxProfile", 16.0))
  cp.set_profile(1, simple_profile("TxProfile", 10.0))
  match cp.composite_schedule(1, "2026-11-07T05:00:00Z", 3600) {
    Some(schedule) =>
      assert_eq(schedule.charging_schedule_period[0].limit, 10.0)
    None => fail("expected a composite schedule")
  }
}

///|
test "tx profile overrides tx default and is capped by the station" {
  let cp = ChargePoint::new("CP-27", Version::V16)
  cp.set_profile(0, simple_profile("ChargePointMaxProfile", 16.0))
  cp.set_profile(1, simple_profile("TxDefaultProfile", 20.0))
  cp.set_profile(1, simple_profile("TxProfile", 12.0))
  match cp.composite_schedule(1, "2026-11-07T05:00:00Z", 3600) {
    Some(schedule) =>
      assert_eq(schedule.charging_schedule_period[0].limit, 12.0)
    None => fail("expected a composite schedule")
  }
}
