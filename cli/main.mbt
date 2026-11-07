// `ocpp` is a small companion binary: run a scripted charging session,
// pretty-print a captured frame, or push many sessions through the state
// machines to see them hold up.

///|
fn main {
  let args = @env.args()
  let command = if args.length() > 1 { args[1] } else { "demo" }
  match command {
    "demo" => demo(args)
    "decode" => decode(args)
    "soak" => soak(args)
    "dump" => dump(args)
    _ => usage()
  }
}

///|
fn usage() -> Unit {
  println("ocpp - OCPP 1.6J / 2.0.1 companion")
  println("")
  println("  ocpp demo [1.6|2.0.1]   run a scripted charging session")
  println("  ocpp decode <json>      explain one frame")
  println("  ocpp soak [n]           run n sessions and report counters")
  println("  ocpp dump [1.6|2.0.1]   print full frames, one per line")
}

///|
fn demo(args : Array[String]) -> Unit {
  let only = if args.length() > 2 { args[2] } else { "both" }
  if only != "2.0.1" {
    show(@station.Version::V16, 3)
  }
  if only != "1.6" {
    if only == "both" {
      println("")
    }
    show(@station.Version::V2, 3)
  }
}

///|
fn show(version : @station.Version, rounds : Int) -> Unit {
  println("OCPP " + version.label() + "   charge point CP-001")
  println("")
  let log = @sim.run(version, rounds)
  for item in log {
    println(
      "  " + pad(item.direction, 8) + pad(item.action, 24) + clip(item.text, 84),
    )
  }
  println("")
  println("  exchanges=" + log.length().to_string())
}

///|
fn decode(args : Array[String]) -> Unit {
  if args.length() < 3 {
    println("usage: ocpp decode <json>")
    return
  }
  let frame = @wire.parse(args[2]) catch {
    _ => {
      println("error: not an OCPP frame")
      return
    }
  }
  match frame {
    @wire.Frame::Call(call) => {
      println("CALL " + call.action + " id=" + call.id)
      println(call.payload.stringify())
    }
    @wire.Frame::Result(result) => {
      println("CALLRESULT id=" + result.id)
      println(result.payload.stringify())
    }
    @wire.Frame::Failure(error) =>
      println(
        "CALLERROR id=" + error.id + " " + error.code + ": " + error.description,
      )
  }
}

///|
fn soak(args : Array[String]) -> Unit {
  let count = if args.length() > 2 {
    match parse_int(args[2]) {
      Some(value) => value
      None => 100
    }
  } else {
    100
  }
  let mut exchanges_16 = 0
  let mut exchanges_2 = 0
  for _ in 0..<count {
    exchanges_16 = exchanges_16 + @sim.run(@station.Version::V16, 3).length()
    exchanges_2 = exchanges_2 + @sim.run(@station.Version::V2, 3).length()
  }
  println("sessions=" + (count * 2).to_string())
  println("1.6J exchanges=" + exchanges_16.to_string())
  println("2.0.1 exchanges=" + exchanges_2.to_string())
}

///|
fn pad(text : String, width : Int) -> String {
  let mut out = text
  while out.length() < width {
    out = out + " "
  }
  out
}

///|
fn clip(text : String, width : Int) -> String {
  if text.length() <= width {
    return text
  }
  let out = StringBuilder()
  for index in 0..<(width - 3) {
    match text.get_char(index) {
      Some(ch) => out.write_char(ch)
      None => ()
    }
  }
  out.write_stringview("...")
  out.to_string()
}

///|
fn parse_int(text : String) -> Int? {
  let mut value = 0
  let mut seen = false
  for index in 0..<text.length() {
    let code = text.get_char(index).unwrap().to_int()
    if code < 48 || code > 57 {
      return None
    }
    value = value * 10 + (code - 48)
    seen = true
  }
  if seen {
    Some(value)
  } else {
    None
  }
}

///|
fn dump(args : Array[String]) -> Unit {
  let only = if args.length() > 2 { args[2] } else { "1.6" }
  let version = if only == "2.0.1" {
    @station.Version::V2
  } else {
    @station.Version::V16
  }
  for item in @sim.run(version, 3) {
    println(item.direction + "\t" + item.action + "\t" + item.text)
  }
}
