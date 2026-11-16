// The scripted run is the closest thing to an integration test: two real
// state machines, real frames, no mocks.

///|
test "1.6 session walks boot to status" {
  let log = run(@station.Version::V16, 3)
  assert_true(log.length() >= 12)
  assert_eq(log[0].action, "BootNotification")
  assert_eq(log[0].direction, "cp→cs")
  let mut stops = 0
  for item in log {
    if item.action == "StopTransaction" {
      stops = stops + 1
    }
  }
  assert_eq(stops, 1)
}

///|

///|
test "every central reply follows a charge point call" {
  let log = run(@station.Version::V16, 1)
  let mut index = 0
  while index + 1 < log.length() {
    assert_eq(log[index].direction, "cp→cs")
    assert_eq(log[index + 1].direction, "cs→cp")
    index = index + 2
  }
}
