// One mailbox per direction is enough to describe any transport: the sender
// posts, the receiver takes. These tests pin FIFO order because OCPP replies
// are matched by message id, not by arrival assumptions.

///|
test "mailbox is fifo" {
  let box = Mailbox::new()
  box.post("one")
  box.post("two")
  assert_eq(box.take(), Some("one"))
  assert_eq(box.take(), Some("two"))
  assert_eq(box.take(), None)
  assert_eq(box.delivered_count(), 2)
}

///|
test "relay moves one frame at a time" {
  let outbox = Mailbox::new()
  let inbox = Mailbox::new()
  outbox.post("a")
  outbox.post("b")
  assert_true(relay(outbox, inbox))
  assert_eq(outbox.pending_count(), 1)
  assert_eq(inbox.pending_count(), 1)
  assert_eq(relay_all(outbox, inbox), 1)
  assert_eq(inbox.pending_count(), 2)
  assert_true(!relay(outbox, inbox))
}

///|
test "a matching response clears the pending call" {
  let table = Correlator::new()
  table.expect("1", "BootNotification", 100, 30)
  assert_eq(table.size(), 1)
  let matched = table.accept("1", 110)
  assert_true(matched is Some(_))
  assert_eq(table.size(), 0)
}

///|
test "unknown and expired ids are rejected" {
  let table = Correlator::new()
  table.expect("1", "Heartbeat", 100, 30)
  assert_true(table.accept("2", 110) is None)
  assert_true(table.accept("1", 131) is None)
  assert_eq(table.size(), 1)
}

///|
test "expiry reports late ids once" {
  let table = Correlator::new()
  table.expect("1", "Authorize", 100, 30)
  table.expect("2", "MeterValues", 100, 60)
  let gone = table.expired(140)
  assert_eq(gone, ["1"])
  assert_eq(table.size(), 1)
  assert_eq(table.expired(161), ["2"])
  assert_eq(table.size(), 0)
}
