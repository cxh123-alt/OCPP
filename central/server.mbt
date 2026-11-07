// The central system side. It answers both protocol revisions because the
// transport does not tell it which one a station speaks: the shape of the
// payload does. Boot, authorize and meter values each have a discriminator.

///|
pub(all) struct StationRecord {
  id : String
  mut boots : Int
  mut authorizes : Int
  mut meters : Int
  mut transactions : Int
  mut last_status : String
} derive(Debug, Eq)

///|
pub(all) struct Central {
  mut stations : Map[String, StationRecord]
  mut next_transaction : Int
  mut clock : @schema.ClockTime
}

///|
pub fn Central::new(clock : @schema.ClockTime) -> Central {
  { stations: Map([]), next_transaction: 0, clock }
}

///|
pub fn Central::station_count(self : Central) -> Int {
  self.stations.length()
}

///|
pub fn Central::transaction_count(self : Central) -> Int {
  self.next_transaction
}

///|
fn Central::record(self : Central, id : String) -> StationRecord {
  match self.stations.get(id) {
    Some(record) => record
    None => {
      let record : StationRecord = {
        id,
        boots: 0,
        authorizes: 0,
        meters: 0,
        transactions: 0,
        last_status: "Unknown",
      }
      self.stations.set(id, record)
      record
    }
  }
}

///|
pub fn Central::handle(self : Central, text : String) -> Array[String] {
  let replies : Array[String] = []
  let frame = try {
    @wire.parse(text)
  } catch {
    _ => return replies
  }
  match frame {
    @wire.Frame::Call(call) => {
      let answer = self.answer(call)
      match answer {
        Some(value) => replies.push(value)
        None => ()
      }
    }
    _ => ()
  }
  replies
}

///|
fn Central::answer(self : Central, call : @wire.Call) -> String? {
  let payload = call.payload
  match call.action {
    "BootNotification" => {
      let is_v2 = has_key(payload, "chargingStation")
      let record = self.record(station_id(payload, is_v2))
      record.boots = record.boots + 1
      let body = @schema.obj([
        ("status", @schema.text("Accepted")),
        ("currentTime", @schema.text(self.clock.iso())),
        ("interval", @schema.integer(300)),
      ])
      Some(result_frame(call.id, body))
    }
    "Heartbeat" => {
      let body = @schema.obj([("currentTime", @schema.text(self.clock.iso()))])
      Some(result_frame(call.id, body))
    }
    "Authorize" => {
      let is_v2 = has_key(payload, "idToken")
      let tag = if is_v2 {
        @schema.get_string(inner(payload, "idToken"), "idToken") catch {
          _ => ""
        }
      } else {
        @schema.get_string(payload, "idTag") catch {
          _ => ""
        }
      }
      let accepted = tag != "BAD"
      let status = if accepted { "Accepted" } else { "Invalid" }
      let body = if is_v2 {
        @schema.obj([("idTokenInfo", @schema.obj([("status", @schema.text(status))]))])
      } else {
        @schema.obj([("idTagInfo", @schema.obj([("status", @schema.text(status))]))])
      }
      Some(result_frame(call.id, body))
    }
    "StartTransaction" => {
      self.next_transaction = self.next_transaction + 1
      let record = self.record("station")
      record.transactions = record.transactions + 1
      let body = @schema.obj([
        ("transactionId", @schema.integer(self.next_transaction)),
        ("idTagInfo", @schema.obj([("status", @schema.text("Accepted"))])),
      ])
      Some(result_frame(call.id, body))
    }
    "StopTransaction" => {
      let record = self.record("station")
      record.transactions = record.transactions + 1
      Some(result_frame(call.id, @schema.empty()))
    }
    "TransactionEvent" => {
      self.next_transaction = self.next_transaction + 1
      let body = @schema.obj([
        ("idTokenInfo", @schema.obj([("status", @schema.text("Accepted"))])),
      ])
      Some(result_frame(call.id, body))
    }
    "MeterValues" => {
      let record = self.record("station")
      record.meters = record.meters + 1
      Some(result_frame(call.id, @schema.empty()))
    }
    "StatusNotification" => {
      let status = if has_key(payload, "connectorStatus") {
        @schema.get_string(payload, "connectorStatus") catch {
          _ => "Unknown"
        }
      } else {
        @schema.get_string(payload, "status") catch {
          _ => "Unknown"
        }
      }
      let record = self.record("station")
      record.last_status = status
      Some(result_frame(call.id, @schema.empty()))
    }
    "Reset" => {
      let body = @schema.obj([("status", @schema.text("Accepted"))])
      Some(result_frame(call.id, body))
    }
    _ => Some(error_frame(call.id, "NotImplemented", "action not implemented"))
  }
}

///|
fn station_id(payload : Json, is_v2 : Bool) -> String {
  if is_v2 {
    let station = inner(payload, "chargingStation")
    let serial = try {
      @schema.opt_string(station, "serialNumber")
    } catch {
      _ => None
    }
    match serial {
      Some(value) => value
      None =>
        try {
          @schema.get_string(station, "model")
        } catch {
          _ => "unknown"
        }
    }
  } else {
    let serial = try {
      @schema.opt_string(payload, "chargePointSerialNumber")
    } catch {
      _ => None
    }
    match serial {
      Some(value) => value
      None =>
        try {
          @schema.get_string(payload, "chargePointModel")
        } catch {
          _ => "unknown"
        }
    }
  }
}

///|
fn has_key(json : Json, key : String) -> Bool {
  match json {
    Json::Object(fields) => fields.contains(key)
    _ => false
  }
}

///|
fn inner(json : Json, key : String) -> Json {
  match json {
    Json::Object(fields) =>
      match fields.get(key) {
        Some(value) => value
        None => @schema.empty()
      }
    _ => @schema.empty()
  }
}

///|
fn result_frame(id : String, payload : Json) -> String {
  @wire.encode(@wire.Frame::Result({ id, payload }))
}

///|
fn error_frame(id : String, code : String, description : String) -> String {
  @wire.encode(
    @wire.Frame::Failure({ id, code, description, details: @schema.empty() }),
  )
}
