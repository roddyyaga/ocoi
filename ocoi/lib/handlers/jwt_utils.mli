(** Defines utilities for working with {{: https://jwt.io/introduction/} JWT tokens}

    Note that [algorithm] in this code and documentation refers to the JWT algorithm type, which specifies the key used
    for signatures as well as the choice of algorithm. Instances of it are created with [Jwt.HS256 "My secret key"]. *)

open Base

(** The result from verifying and decoding a JWT token

Gives the payload of the token if the token was correctly formatted and had a valid signature, [SignatureMismatch]
if it was correctly formatted but did not have the right signature, and [FormatError] if it was incorrctly
formatted. *)
type verify_decode_result =
  | Payload of Jwt.payload
  | SignatureMismatch
  | FormatError

val verify : algorithm:Jwt.algorithm -> Jwt.t -> bool
(** [verify ~algorithm token] checks whether the signature of [token] is what it should be given the signature algorithm
    and secret key specified by [algorithm] *)

val verify_and_decode :
  algorithm:Jwt.algorithm -> string -> verify_decode_result
(** [verify ~algorithm token_string] first parses [token_string] into a JWT token (or returns [FormatError] if this
     can't be done). It then verifies that the signature of the token is what it should be using the details in
     [algorithm], returning the payload of the token if it is and [SignatureMismatch] otherwise. *)

val make_token : algorithm:Jwt.algorithm -> (string * string) list -> Jwt.t
(** [make_token ~algorithm [(key1, value1); (key2, value2); ...]] creates a JWT token from a list of claims as key-value
    tuples using some algorithm. *)

val make_and_encode :
  algorithm:Jwt.algorithm -> (string * string) list -> string
(** [make_and_encode ~algorithm claims] calls [make_token ~algorithm claims] and encodes the result as a base64 string. *)

val get_claim : string -> Jwt.payload -> string option
(** [get_claim "claim" payload] returns [Some v] if [v] is the value associated with ["claim"] in [payload] or [None] if ["claim"] is not present in the token. *)
