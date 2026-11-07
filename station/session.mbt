// The charge point side of a conversation. Every method returns the exact
// text that would go on the WebSocket, which keeps the state machine usable
// from a CLI, a test, or a real transport without changes.

///|
pub(all) struct Session {
  cp : ChargePoint
  mut clock : @schema.ClockTime
} derive(Debug, Eq)

///|
pub fn Session::new(cp : ChargePoint, clock : @schema.ClockTime) -> Session {
  { cp, clock, }
}

///|
fn Session::now(self : Session) -> String {
  self.clock.iso()
}

///|
pub fn Session::boot_frame(self : Session) -> String {
  match self.cp.version {
    V16 => {
      let payload = @v16.Request::BootNotification({
        charge_point_model: self.cp.model,
        charge_point_vendor: self.cp.vendor,
        charge_point_serial_number: Some(self.cp.id),
        firmware_version: Some("1.0.0"),
        iccid: None,
        imsi: None,
        meter_serial_number: None,
        meter_type: None,
      })
      call_frame16(self, payload)
    }
    V2 => {
      let payload = @v2.Request::BootNotification({
        reason: @v2.BootReason::PowerUp,
        station: {
          model: self.cp.model,
          vendor: self.cp.vendor,
          serial_number: Some(self.cp.id),
          firmware_version: Some("1.0.0"),
        },
      })
      call_frame2(self, payload)
    }
  }
}

///|
pub fn Session::heartbeat_frame(self : Session) -> String {
  match self.cp.version {
    V16 => call_frame16(self, @v16.Request::Heartbeat)
    V2 => call_frame2(self, @v2.Request::Heartbeat)
  }
}

///|
pub fn Session::authorize_frame(self : Session, tag : String) -> String {
  match self.cp.version {
    V16 => call_frame16(self, @v16.Request::Authorize({ id_tag: tag, }))
    V2 =>
      call_frame2(
        self,
        @v2.Request::Authorize({ value: tag, kind: @v2.IdTokenKind::Local, }),
      )
  }
}

///|
pub fn Session::status_frame(self : Session) -> String {
  match self.cp.version {
    V16 =>
      call_frame16(
        self,
        @v16.Request::StatusNotification({
          connector_id: 1,
          error_code: "NoError",
          status: self.cp.connector,
          timestamp: Some(self.now()),
        }),
      )
    V2 =>
      call_frame2(
        self,
        @v2.Request::StatusNotification({
          timestamp: self.now(),
          connector_status: self.cp.connector,
          evse_id: 1,
          connector_id: 1,
        }),
      )
  }
}

///|
pub fn Session::start_frame(
  self : Session,
  tag : String,
  transaction_id : Int,
) -> String {
  match self.cp.version {
    V16 => {
      self.cp.begin_transaction(transaction_id)
      let payload = @v16.Request::StartTransaction({
        connector_id: 1,
        id_tag: tag,
        meter_start: self.cp.meter_wh,
        reservation_id: None,
        timestamp: self.now(),
      })
      call_frame16(self, payload)
    }
    V2 => {
      self.cp.begin_transaction(transaction_id)
      let payload = @v2.Request::TransactionEvent({
        event_type: @schema.TransactionEventKind::Started,
        timestamp: self.now(),
        trigger_reason: "CablePluggedIn",
        seq_no: self.cp.seq_no,
        transaction_info: {
          transaction_id: self.cp.transaction_label(),
          charging_state: Some("Charging"),
          stopped_reason: None,
        },
        id_token: Some({ value: tag, kind: @v2.IdTokenKind::Local, }),
        evse_id: Some(1),
        meter_value: None,
      })
      call_frame2(self, payload)
    }
  }
}

///|
pub fn Session::meter_frame(self : Session, wh : Int, seconds : Int) -> String {
  self.cp.add_energy(wh)
  self.clock = self.clock.advance(seconds)
  let value = (self.cp.meter_wh.to_double() / 1000.0).to_string()
  match self.cp.version {
    V16 =>
      call_frame16(
        self,
        @v16.Request::MeterValues({
          connector_id: 1,
          transaction_id: self.cp.transaction_16,
          meter_value: [
            {
              timestamp: self.now(),
              sampled_value: [
                {
                  value,
                  measurand: Some("Energy.Active.Import.Register"),
                  context: Some("Sample.Periodic"),
                  format: None,
                  unit: Some("kWh"),
                },
              ],
            },
          ],
        }),
      )
    V2 => {
      self.cp.seq_no = self.cp.seq_no + 1
      call_frame2(
        self,
        @v2.Request::MeterValues({
          evse_id: 1,
          meter_value: [
            {
              timestamp: self.now(),
              sampled_value: [
                {
                  value,
                  measurand: Some("Energy.Active.Import.Register"),
                  context: Some("Sample.Periodic"),
                  phase: None,
                },
              ],
            },
          ],
        }),
      )
    }
  }
}

///|
pub fn Session::stop_frame(
  self : Session,
  reason : String,
  seconds : Int,
) -> String {
  self.cp.end_transaction()
  self.clock = self.clock.advance(seconds)
  match self.cp.version {
    V16 => {
      let transaction_id = match self.cp.transaction_16 {
        Some(value) => value
        None => 0
      }
      call_frame16(
        self,
        @v16.Request::StopTransaction({
          transaction_id,
          meter_stop: self.cp.meter_wh,
          timestamp: self.now(),
          reason: Some(reason),
        }),
      )
    }
    V2 => {
      self.cp.seq_no = self.cp.seq_no + 1
      call_frame2(
        self,
        @v2.Request::TransactionEvent({
          event_type: @schema.TransactionEventKind::Ended,
          timestamp: self.now(),
          trigger_reason: "EVDisconnected",
          seq_no: self.cp.seq_no,
          transaction_info: {
            transaction_id: self.cp.transaction_label(),
            charging_state: None,
            stopped_reason: Some(reason),
          },
          id_token: None,
          evse_id: Some(1),
          meter_value: None,
        }),
      )
    }
  }
}

///|
/// React to a central-system call. Returns the frames to send back.
pub fn Session::handle(self : Session, text : String) -> Array[String] {
  let replies : Array[String] = []
  let frame = @wire.parse(text) catch { _ => return replies }
  match frame {
    @wire.Frame::Call(call) => {
      let reply = self.reply_to(call)
      match reply {
        Some(value) => replies.push(value)
        None => ()
      }
    }
    _ => ()
  }
  replies
}

///|
fn Session::reply_to(self : Session, call : @wire.Call) -> String? {
  match self.cp.version {
    V16 => self.reply_16(call)
    V2 => self.reply_2(call)
  }
}

///|
fn Session::reply_16(self : Session, call : @wire.Call) -> String? {
  match call.action {
    "RemoteStartTransaction" => {
      let request = @v16.RemoteStartTransaction::from_json(call.payload) catch {
        _ => return None
      }
      let accepted = request.id_tag.length() > 0
      if accepted {
        self.cp.begin_transaction(101)
      }
      let payload : @v16.RequestStatusResponse = {
        status: if accepted {
          @schema.RequestStatus::Accepted
        } else {
          @schema.RequestStatus::Rejected
        },
      }
      Some(result_frame(call.id, payload.to_json()))
    }
    "RemoteStopTransaction" => {
      self.cp.end_transaction()
      let accepted : @v16.RequestStatusResponse = {
        status: @schema.RequestStatus::Accepted,
      }
      Some(result_frame(call.id, accepted.to_json()))
    }
    "Reset" => {
      let payload : @v16.RequestStatusResponse = {
        status: @schema.RequestStatus::Accepted,
      }
      Some(result_frame(call.id, payload.to_json()))
    }
    _ => Some(error_frame(call.id, @wire.NOT_SUPPORTED, "action not supported"))
  }
}

///|
fn Session::reply_2(self : Session, call : @wire.Call) -> String? {
  match call.action {
    "RequestStartTransaction" => {
      let request = @v2.RequestStartTransaction::from_json(call.payload) catch {
        _ => return None
      }
      self.cp.begin_transaction(request.remote_start_id)
      let payload : @v2.RequestStartResponse = {
        status: @schema.RequestStatus::Accepted,
        transaction_id: Some(self.cp.transaction_label()),
      }
      Some(result_frame(call.id, payload.to_json()))
    }
    "RequestStopTransaction" => {
      self.cp.end_transaction()
      let stop_status : @v2.RequestStatusResponse = {
        status: @schema.RequestStatus::Accepted,
      }
      Some(result_frame(call.id, stop_status.to_json()))
    }
    "Reset" => {
      let payload : @v2.RequestStatusResponse = {
        status: @schema.RequestStatus::Accepted,
      }
      Some(result_frame(call.id, payload.to_json()))
    }
    _ => Some(error_frame(call.id, @wire.NOT_SUPPORTED, "action not supported"))
  }
}
