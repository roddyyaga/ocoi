(** Defines utilities for working with {{: https://jwt.io/introduction/} JWT tokens} *)

open Base

val verify_and_decode :
  jwk:Jose.Jwk.priv Jose.Jwk.t ->
  string ->
  ( Jose.Jwt.payload,
    [> `Expired | `Invalid_signature | `Msg of string ] )
  Result.t
(** [verify ~jwk token_string] first parses [token_string] into a JWT token (or returns [FormatError] if this
     can't be done). It then verifies that the signature of the token is what it should be using the details in
     [jwk], returning the payload of the token if it is and [SignatureMismatch] otherwise. *)

val make_token :
  jwk:Jose.Jwk.priv Jose.Jwk.t -> (string * string) list -> Jose.Jwt.t
(** [make_token ~jwk [(key1, value1); (key2, value2); ...]] creates a JWT token from a list of claims as key-value
    tuples using some jwk. *)

val make_and_encode :
  jwk:Jose.Jwk.priv Jose.Jwk.t -> (string * string) list -> string
(** [make_and_encode ~jwk claims] calls [make_token ~algorithm claims] and encodes the result as a base64 string. *)

val get_claim : string -> Jose.Jwt.payload -> string option
(** [get_claim "claim" payload] returns [Some v] if [v] is the value associated with ["claim"] in [payload] or [None] if ["claim"] is not present in the token. *)
