// One mailbox per direction is enough to describe any transport: the sender
// posts, the receiver takes. These tests pin FIFO order because OCPP replies
// are matched by message id, not by arrival assumptions.

test "mailbox is fifo" {
  let box = Mailbox::new()
  box.post("one")
  box.post("two")
  assert_eq(box.take(), Some("one"))
  assert_eq(box.take(), Some("two"))
  assert_eq(box.take(), None)
  assert_eq(box.delivered_count(), 2)
}

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
