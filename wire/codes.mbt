// The six codes OCPP allows in a CALLERROR. They are fixed strings, so they
// are easy to typo and worth pinning here.

///|
pub const NOT_IMPLEMENTED : String = "NotImplemented"

///|
pub const NOT_SUPPORTED : String = "NotSupported"

///|
pub const INTERNAL_ERROR : String = "InternalError"

///|
pub const PROTOCOL_ERROR : String = "ProtocolError"

///|
pub const SECURITY_ERROR : String = "SecurityError"

///|
pub const FORMATION_VIOLATION : String = "FormationViolation"

///|
pub const PROPERTY_CONSTRAINT_VIOLATION : String = "PropertyConstraintViolation"

///|
pub const OCCURENCE_CONSTRAINT_VIOLATION : String = "OccurenceConstraintViolation"

///|
pub const TYPE_CONSTRAINT_VIOLATION : String = "TypeConstraintViolation"

///|
pub const GENERIC_ERROR : String = "GenericError"

///|
pub fn known_error_code(code : String) -> Bool {
  code == NOT_IMPLEMENTED ||
  code == NOT_SUPPORTED ||
  code == INTERNAL_ERROR ||
  code == PROTOCOL_ERROR ||
  code == SECURITY_ERROR ||
  code == FORMATION_VIOLATION ||
  code == PROPERTY_CONSTRAINT_VIOLATION ||
  code == OCCURENCE_CONSTRAINT_VIOLATION ||
  code == TYPE_CONSTRAINT_VIOLATION ||
  code == GENERIC_ERROR
}
