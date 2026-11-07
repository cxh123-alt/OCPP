// The protocol layer produces and consumes text. A real deployment puts a
// WebSocket between those two points; this package is the seam, kept small
// enough to swap for any transport without touching the state machines.

///|
/// A FIFO of frames in one direction.
pub(all) struct Mailbox {
  mut pending : Array[String]
  mut delivered : Int
} derive(Debug, Eq)

///|
pub fn Mailbox::new() -> Mailbox {
  { pending: [], delivered: 0 }
}

///|
pub fn Mailbox::post(self : Mailbox, text : String) -> Unit {
  self.pending.push(text)
}

///|
pub fn Mailbox::take(self : Mailbox) -> String? {
  if self.pending.length() == 0 {
    return None
  }
  let text = self.pending[0]
  let rest : Array[String] = []
  for index in 1..<self.pending.length() {
    rest.push(self.pending[index])
  }
  self.pending = rest
  self.delivered = self.delivered + 1
  Some(text)
}

///|
pub fn Mailbox::pending_count(self : Mailbox) -> Int {
  self.pending.length()
}

///|
pub fn Mailbox::delivered_count(self : Mailbox) -> Int {
  self.delivered
}

///|
/// Move at most one frame from `from` to `to`. Returns whether anything moved.
pub fn relay(from : Mailbox, to : Mailbox) -> Bool {
  match from.take() {
    None => false
    Some(text) => {
      to.post(text)
      true
    }
  }
}

///|
/// Drain `from` into `to`, returning how many frames moved.
pub fn relay_all(from : Mailbox, to : Mailbox) -> Int {
  let mut moved = 0
  while relay(from, to) {
    moved = moved + 1
  }
  moved
}
