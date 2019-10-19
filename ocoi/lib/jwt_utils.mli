(** Defines utilities for working with {{: https://jwt.io/introduction/} JWT tokens}. *)

type verify_decode_result =
  | Payload of Jwt.payload
  | SignatureMismatch
  | FormatError
      (** The result from verifying and decoding a JWT token.

Gives the payload of the token if the token was correctly formatted and had a valid signature, [SignatureMismatch]
if it was correctly formatted but did not have the right signature, and [FormatError] if it was incorrctly
formatted. *)

val verify : algorithm:Jwt.algorithm -> Jwt.t -> bool
(** [verify ~algorithm token] checks whether the signature of [token] is what it should be given the signature algorithm
    and secret key specified by [algorithm]. *)

val verify_and_decode :
  algorithm:Jwt.algorithm -> string -> verify_decode_result
(** [verify ~algorithm token_string] first parses [token_string] into a JWT token (or returns [FormatError] if this
     can't be done). It then verifies that the signature of the token is what it should be using the details in
     [algorithm], returning the payload of the token if it is and [SignatureMismatch] otherwise. *)
