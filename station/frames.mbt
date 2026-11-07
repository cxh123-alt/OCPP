// Frame construction lives apart from the state machine so the session file
// reads as a sequence of decisions rather than JSON assembly.

///|
fn call_frame16(session : Session, payload : @v16.Request) -> String {
  @wire.encode(
    @wire.Frame::Call({
      id: session.cp.message_id(),
      action: payload.action(),
      payload: payload.to_json(),
    }),
  )
}

///|
fn call_frame2(session : Session, payload : @v2.Request) -> String {
  @wire.encode(
    @wire.Frame::Call({
      id: session.cp.message_id(),
      action: payload.action(),
      payload: payload.to_json(),
    }),
  )
}

///|
fn result_frame(id : String, payload : Json) -> String {
  @wire.encode(@wire.Frame::Result({ id, payload }))
}

///|
fn error_frame(id : String, code : String, description : String) -> String {
  @wire.encode(
    @wire.Frame::Failure({
      id,
      code,
      description,
      details: @schema.empty(),
    }),
  )
}
