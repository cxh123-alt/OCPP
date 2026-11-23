// The charge point side of a 1.6J conversation. Every method returns the exact
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
  call_frame16(
    self,
    @v16.Request::BootNotification({
      charge_point_model: self.cp.model,
      charge_point_vendor: self.cp.vendor,
      charge_point_serial_number: Some(self.cp.id),
      firmware_version: Some("1.0.0"),
      iccid: None,
      imsi: None,
      meter_serial_number: None,
      meter_type: None,
    }),
  )
}

///|
pub fn Session::heartbeat_frame(self : Session) -> String {
  call_frame16(self, @v16.Request::Heartbeat)
}

///|
pub fn Session::authorize_frame(self : Session, tag : String) -> String {
  self.cp.cache_tag(tag)
  call_frame16(self, @v16.Request::Authorize({ id_tag: tag, }))
}

///|
pub fn Session::status_frame(self : Session) -> String {
  call_frame16(
    self,
    @v16.Request::StatusNotification({
      connector_id: 1,
      error_code: "NoError",
      status: self.cp.connector,
      timestamp: Some(self.now()),
    }),
  )
}

///|
pub fn Session::start_frame(
  self : Session,
  tag : String,
  transaction_id : Int,
) -> String {
  self.cp.begin_transaction(transaction_id)
  call_frame16(
    self,
    @v16.Request::StartTransaction({
      connector_id: 1,
      id_tag: tag,
      meter_start: self.cp.meter_wh,
      reservation_id: None,
      timestamp: self.now(),
    }),
  )
}

///|
pub fn Session::meter_frame(self : Session, wh : Int, seconds : Int) -> String {
  self.cp.add_energy(wh)
  self.clock = self.clock.advance(seconds)
  let value = (self.cp.meter_wh.to_double() / 1000.0).to_string()
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
}

///|
pub fn Session::stop_frame(
  self : Session,
  reason : String,
  seconds : Int,
) -> String {
  self.cp.end_transaction()
  self.clock = self.clock.advance(seconds)
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

///|
/// React to a central-system call. Returns the frames to send back.
pub fn Session::handle(self : Session, text : String) -> Array[String] {
  let replies : Array[String] = []
  let frame = @wire.parse(text) catch { _ => return replies }
  match frame {
    @wire.Frame::Call(call) => {
      let reply = self.reply(call)
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
fn Session::reply(self : Session, call : @wire.Call) -> String? {
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
      self.cp.reset()
      let payload : @v16.RequestStatusResponse = {
        status: @schema.RequestStatus::Accepted,
      }
      Some(result_frame(call.id, payload.to_json()))
    }
    "ChangeConfiguration" => {
      let request = @v16.ChangeConfiguration::from_json(call.payload) catch {
        _ => return None
      }
      let status = match self.cp.set_config(request.key, request.value) {
        "Accepted" => @schema.ConfigurationStatus::Accepted
        "NotSupported" => @schema.ConfigurationStatus::NotSupported
        _ => @schema.ConfigurationStatus::Rejected
      }
      let payload : @v16.ChangeConfigurationResponse = { status, }
      Some(result_frame(call.id, payload.to_json()))
    }
    "GetConfiguration" => {
      let request = @v16.GetConfiguration::from_json(call.payload) catch {
        _ => return None
      }
      let all = self.cp.config()
      let keys : Array[@v16.ConfigurationKey] = []
      let unknown : Array[String] = []
      match request.keys {
        Some(wanted) =>
          for key in wanted {
            let mut found = false
            for item in all {
              if item.0 == key {
                found = true
                keys.push({ key, is_readonly: false, value: Some(item.1), })
              }
            }
            if !found {
              unknown.push(key)
            }
          }
        None =>
          for item in all {
            keys.push({ key: item.0, is_readonly: false, value: Some(item.1), })
          }
      }
      let payload : @v16.GetConfigurationResponse = {
        configuration_key: keys,
        unknown_key: if unknown.length() > 0 {
          Some(unknown)
        } else {
          None
        },
      }
      Some(result_frame(call.id, payload.to_json()))
    }
    "RemoteTrigger" => {
      let _request = @v16.RemoteTrigger::from_json(call.payload) catch {
        _ => return None
      }
      let payload : @v16.RequestStatusResponse = {
        status: @schema.RequestStatus::Accepted,
      }
      Some(result_frame(call.id, payload.to_json()))
    }
    "ChangeAvailability" => {
      let request = @v16.ChangeAvailability::from_json(call.payload) catch {
        _ => return None
      }
      self.cp.set_available(request.kind == "Operative")
      let payload : @v16.ChangeAvailabilityResponse = { status: "Accepted", }
      Some(result_frame(call.id, payload.to_json()))
    }
    "ClearCache" => {
      self.cp.clear_cache()
      let payload : @v16.ClearCacheResponse = { status: "Accepted", }
      Some(result_frame(call.id, payload.to_json()))
    }
    "DataTransfer" => {
      let _request = @v16.DataTransfer::from_json(call.payload) catch {
        _ => return None
      }
      let payload : @v16.DataTransferResponse = {
        status: "Accepted",
        data: None,
      }
      Some(result_frame(call.id, payload.to_json()))
    }
    "UnlockConnector" => {
      let _request = @v16.UnlockConnector::from_json(call.payload) catch {
        _ => return None
      }
      self.cp.unlock()
      let payload : @v16.UnlockConnectorResponse = { status: "Unlocked", }
      Some(result_frame(call.id, payload.to_json()))
    }
    "UpdateFirmware" => {
      let request = @v16.UpdateFirmware::from_json(call.payload) catch {
        _ => return None
      }
      self.cp.store_firmware(request.location, request.retrieve_date)
      Some(result_frame(call.id, @schema.empty()))
    }
    "GetLocalListVersion" => {
      let payload : @v16.GetLocalListVersionResponse = {
        list_version: self.cp.local_list_version(),
      }
      Some(result_frame(call.id, payload.to_json()))
    }
    "SendLocalList" => {
      let request = @v16.SendLocalList::from_json(call.payload) catch {
        _ => return None
      }
      let entries : Array[(String, Bool)] = []
      match request.local_authorization_list {
        Some(items) =>
          for item in items {
            entries.push((item.id_tag, item.id_tag_info is Some(_)))
          }
        None => ()
      }
      let status = self.cp.apply_local_list(
        request.list_version,
        entries,
        request.update_type,
      )
      let payload : @v16.SendLocalListResponse = { status, }
      Some(result_frame(call.id, payload.to_json()))
    }
    "ReserveNow" => {
      let request = @v16.ReserveNow::from_json(call.payload) catch {
        _ => return None
      }
      ignore(self.cp.release_expired(self.now()))
      let status = self.cp.reserve(
        request.reservation_id,
        request.expiry_date,
        request.connector_id,
      )
      let payload : @v16.ReserveNowResponse = { status, }
      Some(result_frame(call.id, payload.to_json()))
    }
    "CancelReservation" => {
      let request = @v16.CancelReservation::from_json(call.payload) catch {
        _ => return None
      }
      let accepted = self.cp.cancel_reservation(request.reservation_id)
      let payload : @v16.CancelReservationResponse = {
        status: if accepted {
          "Accepted"
        } else {
          "Rejected"
        },
      }
      Some(result_frame(call.id, payload.to_json()))
    }
    "SetChargingProfile" => {
      let request = @v16.SetChargingProfile::from_json(call.payload) catch {
        _ => return None
      }
      self.cp.set_profile(request.connector_id, request.cs_charging_profiles)
      let payload : @v16.SetChargingProfileResponse = { status: "Accepted", }
      Some(result_frame(call.id, payload.to_json()))
    }
    "ClearChargingProfile" => {
      let request = @v16.ClearChargingProfile::from_json(call.payload) catch {
        _ => return None
      }
      let removed = self.cp.clear_profiles(
        request.id,
        request.connector_id,
        request.charging_profile_purpose,
        request.stack_level,
      )
      let payload : @v16.ClearChargingProfileResponse = {
        status: if removed > 0 {
          "Accepted"
        } else {
          "Unknown"
        },
      }
      Some(result_frame(call.id, payload.to_json()))
    }
    "GetCompositeSchedule" => {
      let request = @v16.GetCompositeSchedule::from_json(call.payload) catch {
        _ => return None
      }
      let payload : @v16.GetCompositeScheduleResponse = {
        status: "Accepted",
        schedule: self.cp.composite_schedule(
          request.connector_id,
          self.now(),
          request.duration,
        ),
      }
      Some(result_frame(call.id, payload.to_json()))
    }
    "GetDiagnostics" => {
      let _request = @v16.GetDiagnostics::from_json(call.payload) catch {
        _ => return None
      }
      let payload : @v16.GetDiagnosticsResponse = {
        file_name: Some("diag-20261107.log"),
      }
      Some(result_frame(call.id, payload.to_json()))
    }
    _ => Some(error_frame(call.id, @wire.NOT_SUPPORTED, "action not supported"))
  }
}
