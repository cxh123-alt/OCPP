// A scripted charger talking to a scripted central system. This is the only
// place that knows both sides, which keeps the two state machines free of
// each other and makes the demo a plain function.

///|
pub(all) struct Exchange {
  direction : String
  action : String
  text : String
} derive(Debug, Eq)

///|
pub fn run(version : @station.Version, meter_rounds : Int) -> Array[Exchange] {
  let clock : @schema.ClockTime = {
    year: 2026,
    month: 11,
    day: 7,
    hour: 5,
    minute: 0,
    second: 0,
  }
  let session = @station.Session::new(
    @station.ChargePoint::new("CP-001", version),
    clock,
  )
  let central = @central.Central::new(clock)
  let log : Array[Exchange] = []
  pump(log, session, central, session.boot_frame())
  pump(log, session, central, session.authorize_frame("TAG-1"))
  pump(log, session, central, session.start_frame("TAG-1", 1))
  for round in 0..<meter_rounds {
    pump(log, session, central, session.meter_frame(750 + round * 100, 60))
  }
  pump(log, session, central, session.stop_frame("Local", 0))
  pump(log, session, central, session.status_frame())
  log
}

///|
fn pump(
  log : Array[Exchange],
  session : @station.Session,
  central : @central.Central,
  outgoing : String,
) -> Unit {
  record(log, "cp→cs", outgoing)
  let replies = central.handle(outgoing)
  for reply in replies {
    record(log, "cs→cp", reply)
    let follow_ups = session.handle(reply)
    for follow_up in follow_ups {
      record(log, "cp→cs", follow_up)
      ignore(central.handle(follow_up))
    }
  }
}

///|
fn record(log : Array[Exchange], direction : String, text : String) -> Unit {
  log.push({ direction, action: action_of(text), text, })
}

///|
fn action_of(text : String) -> String {
  let frame = @wire.parse(text) catch { _ => return "unparseable" }
  match frame {
    @wire.Frame::Call(call) => call.action
    @wire.Frame::Result(_) => "result"
    @wire.Frame::Failure(_) => "error"
  }
}
