// The revision is a property of the connection, not of the payload. These
// tests pin that: the same Heartbeat object is answered under either binding,
// and a command is encoded with the binding the session was opened with.

///|
test "heartbeat is answered under either binding" {
  let central = Central::new(clock())
  let frame = @wire.encode(
    @wire.Frame::Call({
      id: "1",
      action: "Heartbeat",
      payload: @schema.empty(),
    }),
  )
  assert_eq(central.handle(V16, frame).length(), 1)
  assert_eq(central.handle(V201, frame).length(), 1)
}

///|
test "command16 emits a call with the bound revision" {
  let central = Central::new(clock())
  let call = central.command16(@v16.Reset({ kind: @schema.Soft, }))
  let parsed = @wire.parse(call)
  match parsed {
    @wire.Frame::Call(frame) => {
      assert_eq(frame.action, "Reset")
      assert_eq(frame.id, "cs-1")
      assert_eq(@schema.get_string(frame.payload, "type"), "Soft")
    }
    _ => fail("expected a CALL")
  }
}

///|
test "ambiguous payloads are decoded by the connection binding" {
  let central = Central::new(clock())
  let reset = @wire.encode(
    @wire.Frame::Call({
      id: "2",
      action: "Reset",
      payload: @schema.obj([("type", @schema.text("Soft"))]),
    }),
  )
  assert_eq(central.handle(V16, reset).length(), 1)
  assert_eq(central.handle(V201, reset).length(), 1)
}

///|
test "boot notification records a station under either binding" {
  let clock = clock()
  let body16 = @schema.obj([
    ("chargePointModel", @schema.text("AC-7")),
    ("chargePointVendor", @schema.text("MoonCharge")),
  ])
  let body20 = @schema.obj([
    ("chargingStation", @schema.obj([("model", @schema.text("AC-7"))])),
  ])
  let v16_central = Central::new(clock)
  ignore(
    v16_central.handle(
      V16,
      @wire.encode(
        @wire.Frame::Call({
          id: "3",
          action: "BootNotification",
          payload: body16,
        }),
      ),
    ),
  )
  assert_eq(v16_central.station_count(), 1)
  let v20_central = Central::new(clock)
  ignore(
    v20_central.handle(
      V201,
      @wire.encode(
        @wire.Frame::Call({
          id: "4",
          action: "BootNotification",
          payload: body20,
        }),
      ),
    ),
  )
  assert_eq(v20_central.station_count(), 1)
}

///|
fn clock() -> @schema.ClockTime {
  { year: 2026, month: 11, day: 7, hour: 5, minute: 0, second: 0, }
}
