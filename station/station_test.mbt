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
      assert_eq(keys.length(), 2)
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
  assert_true(session.cp.profile_schedule() is Some(_))
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
  assert_true(session.cp.profile_schedule() is Some(_))
}
