// Small constructors so action encoders read like the payload they build.

///|
pub fn obj(pairs : Array[(String, Json)]) -> Json {
  let fields : Map[String, Json] = Map([])
  for pair in pairs {
    fields.set(pair.0, pair.1)
  }
  Json::object(fields)
}

///|
pub fn text(value : String) -> Json {
  Json::string(value)
}

///|
pub fn number(value : Double) -> Json {
  Json::number(value)
}

///|
pub fn integer(value : Int) -> Json {
  Json::number(value.to_double())
}

///|
pub fn boolean(value : Bool) -> Json {
  Json::boolean(value)
}

///|
pub fn empty() -> Json {
  Json::empty_object()
}
