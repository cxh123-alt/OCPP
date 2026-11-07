// Envelope tests use literal strings so the wire format is checked against
// the spec text rather than against this implementation.

///|
test "call keeps its four slots" {
  let frame = parse("[2,\"42\",\"Heartbeat\",{}]")
  match frame {
    Call(call) => {
      assert_eq(call.id, "42")
      assert_eq(call.action, "Heartbeat")
      assert_true(call.payload is Json::Object(_))
    }
    _ => fail("expected a call")
  }
}

///|
test "result has three slots" {
  let frame = parse("[3,\"42\",{\"currentTime\":\"2026-11-07T05:00:00Z\"}]")
  match frame {
    Result(result) => assert_eq(result.id, "42")
    _ => fail("expected a result")
  }
}

///|
test "error carries a code and description" {
  let frame = parse("[4,\"42\",\"NotSupported\",\"no such action\",{}]")
  match frame {
    Failure(error) => {
      assert_eq(error.code, NOT_SUPPORTED)
      assert_eq(error.description, "no such action")
    }
    _ => fail("expected an error")
  }
}

///|
test "round trip keeps semantics" {
  let original = Frame::Call({
    id: "7",
    action: "Authorize",
    payload: Json::empty_object(),
  })
  let text = encode(original)
  let parsed = parse(text)
  assert_eq(parsed, original)
}

///|
test "arity is enforced per type" {
  let caught = try {
    ignore(parse("[2,\"1\",\"Heartbeat\"]"))
    false
  } catch {
    WireError::WrongArity(_) => true
    _ => false
  }
  assert_true(caught)
}

///|
test "unknown message type is rejected" {
  let caught = try {
    ignore(parse("[9,\"1\",{}]"))
    false
  } catch {
    WireError::UnknownType(_) => true
    _ => false
  }
  assert_true(caught)
}

///|
test "payload must be an object" {
  let caught = try {
    ignore(parse("[2,\"1\",\"Heartbeat\",\"nope\"]"))
    false
  } catch {
    WireError::WrongFieldType(_) => true
    _ => false
  }
  assert_true(caught)
}

///|
test "error codes are known" {
  assert_true(known_error_code("FormationViolation"))
  assert_true(!known_error_code("BadVibes"))
}
