// Reading OCPP payloads means reading JSON objects with a lot of optional
// keys. These helpers keep the per-action decoders short and make the
// failure mode identical everywhere: a named field that is missing or has
// the wrong shape.

///|
pub(all) suberror SchemaError {
  NotAnObject
  MissingField(String)
  WrongType(String)
  UnknownCode(String)
}

///|
pub fn object_of(json : Json) -> Map[String, Json] raise SchemaError {
  match json {
    Json::Object(fields) => fields
    _ => raise NotAnObject
  }
}

///|
pub fn get_string(json : Json, key : String) -> String raise SchemaError {
  let fields = object_of(json)
  match fields.get(key) {
    Some(Json::String(value)) => value
    Some(_) => raise WrongType(key)
    None => raise MissingField(key)
  }
}

///|
pub fn get_bool(json : Json, key : String) -> Bool raise SchemaError {
  let fields = object_of(json)
  match fields.get(key) {
    Some(Json::True) => true
    Some(Json::False) => false
    Some(_) => raise WrongType(key)
    None => raise MissingField(key)
  }
}

///|
pub fn get_int(json : Json, key : String) -> Int raise SchemaError {
  let fields = object_of(json)
  match fields.get(key) {
    Some(Json::Number(value, ..)) => value.to_int()
    Some(_) => raise WrongType(key)
    None => raise MissingField(key)
  }
}

///|
pub fn get_double(json : Json, key : String) -> Double raise SchemaError {
  let fields = object_of(json)
  match fields.get(key) {
    Some(Json::Number(value, ..)) => value
    Some(_) => raise WrongType(key)
    None => raise MissingField(key)
  }
}

///|
pub fn get_array(json : Json, key : String) -> Array[Json] raise SchemaError {
  let fields = object_of(json)
  match fields.get(key) {
    Some(Json::Array(items)) => items
    Some(_) => raise WrongType(key)
    None => raise MissingField(key)
  }
}

///|
pub fn get_object(json : Json, key : String) -> Json raise SchemaError {
  let fields = object_of(json)
  match fields.get(key) {
    Some(value) =>
      match value {
        Json::Object(_) => value
        _ => raise WrongType(key)
      }
    None => raise MissingField(key)
  }
}

///|
pub fn opt_string(json : Json, key : String) -> String? raise SchemaError {
  let fields = object_of(json)
  match fields.get(key) {
    Some(Json::String(value)) => Some(value)
    Some(Json::Null) => None
    Some(_) => raise WrongType(key)
    None => None
  }
}

///|
pub fn opt_int(json : Json, key : String) -> Int? raise SchemaError {
  let fields = object_of(json)
  match fields.get(key) {
    Some(Json::Number(value, ..)) => Some(value.to_int())
    Some(Json::Null) => None
    Some(_) => raise WrongType(key)
    None => None
  }
}

///|
pub fn opt_double(json : Json, key : String) -> Double? raise SchemaError {
  let fields = object_of(json)
  match fields.get(key) {
    Some(Json::Number(value, ..)) => Some(value)
    Some(Json::Null) => None
    Some(_) => raise WrongType(key)
    None => None
  }
}

///|
pub fn opt_bool(json : Json, key : String) -> Bool? raise SchemaError {
  let fields = object_of(json)
  match fields.get(key) {
    Some(Json::True) => Some(true)
    Some(Json::False) => Some(false)
    Some(Json::Null) => None
    Some(_) => raise WrongType(key)
    None => None
  }
}

///|
pub fn opt_array(json : Json, key : String) -> Array[Json]? raise SchemaError {
  let fields = object_of(json)
  match fields.get(key) {
    Some(Json::Array(items)) => Some(items)
    Some(Json::Null) => None
    Some(_) => raise WrongType(key)
    None => None
  }
}
