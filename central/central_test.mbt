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

///|

///|
fn clock() -> @schema.ClockTime {
  { year: 2026, month: 11, day: 7, hour: 5, minute: 0, second: 0, }
}
