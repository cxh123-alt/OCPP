// Correlating a response with its request is a connection concern, not a
// payload concern. The codecs in `wire` only know how to read a `callId`; this
// table is what the connection owner keeps so a late or duplicate response can
// be rejected instead of being dispatched as a new request.

///|
/// One request that has been sent and is waiting for its response.
pub(all) struct PendingCall {
  id : String
  action : String
  deadline : Int
} derive(Debug, Eq)

///|
pub(all) struct Correlator {
  mut calls : Array[PendingCall]
} derive(Debug, Eq)

///|
pub fn Correlator::new() -> Correlator {
  { calls: [], }
}

///|
/// Record an outgoing call. The deadline is absolute, in the same unit the
/// caller uses for its clock.
pub fn Correlator::expect(
  self : Correlator,
  id : String,
  action : String,
  now : Int,
  timeout : Int,
) -> Unit {
  self.calls.push({ id, action, deadline: now + timeout, })
}

///|
/// Match a response. A matching, unexpired call is removed and returned; an
/// unknown or expired id leaves the table unchanged and returns None.
pub fn Correlator::accept(
  self : Correlator,
  id : String,
  now : Int,
) -> PendingCall? {
  let mut found : PendingCall? = None
  let rest : Array[PendingCall] = []
  for call in self.calls {
    if call.id == id && now <= call.deadline && found is None {
      found = Some(call)
    } else {
      rest.push(call)
    }
  }
  if found is Some(_) {
    self.calls = rest
  }
  found
}

///|
/// Remove and return the ids whose deadline has passed.
pub fn Correlator::expired(self : Correlator, now : Int) -> Array[String] {
  let kept : Array[PendingCall] = []
  let gone : Array[String] = []
  for call in self.calls {
    if now > call.deadline {
      gone.push(call.id)
    } else {
      kept.push(call)
    }
  }
  self.calls = kept
  gone
}

///|
pub fn Correlator::size(self : Correlator) -> Int {
  self.calls.length()
}
