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
test "2.0.1 boot nests the station" {
  let session = Session::new(ChargePoint::new("CP-2", Version::V2), clock())
  let text = session.boot_frame()
  match @wire.parse(text) {
    @wire.Frame::Call(call) => {
      let station = @schema.get_object(call.payload, "chargingStation")
      assert_eq(@schema.get_string(station, "serialNumber"), "CP-2")
    }
    _ => fail("expected a call")
  }
}

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
  let session = Session::new(ChargePoint::new("CP-4", Version::V2), clock())
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
  let session = Session::new(ChargePoint::new("CP-6", Version::V2), clock())
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
test "get variables is answered per request item" {
  let session = Session::new(ChargePoint::new("CP-8", Version::V2), clock())
  let command = @wire.encode(
    @wire.Frame::Call({
      id: "cs-4",
      action: "GetVariables",
      payload: @schema.obj([
        (
          "getVariableData",
          Json::array([
            @schema.obj([
              (
                "component",
                @schema.obj([("name", @schema.text("OCPPCommCtrlr"))]),
              ),
              (
                "variable",
                @schema.obj([("name", @schema.text("HeartbeatInterval"))]),
              ),
            ]),
          ]),
        ),
      ]),
    }),
  )
  let replies = session.handle(command)
  assert_eq(replies.length(), 1)
  match @wire.parse(replies[0]) {
    @wire.Frame::Result(result) => {
      let items = @schema.get_array(result.payload, "getVariableResult")
      assert_eq(items.length(), 1)
    }
    _ => fail("expected a result")
  }
}

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
    @wire.Frame::Result(result) => {
      assert_eq(@schema.get_string(result.payload, "fileName"), "diag-20261107.log")
    }
    _ => fail("expected a result")
  }
}