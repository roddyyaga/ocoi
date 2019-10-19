type verify_decode_result =
  | Payload of Jwt.payload
  | SignatureMismatch
  | FormatError

(** Copied from ocaml-jwt and updated for new version of base64 *)
let b64_url_encode str =
  B64.encode ~pad:true ~alphabet:B64.default_alphabet str

let verify ~algorithm token =
  let given_signature = token |> Jwt.signature_of_t |> b64_url_encode in
  let jwt_header = Jwt.header_of_algorithm_and_typ algorithm "JWT" in
  let given_payload = token |> Jwt.payload_of_t in
  let recomputed_token =
    Jwt.t_of_header_and_payload jwt_header given_payload
  in
  let recomputed_signature =
    recomputed_token |> Jwt.signature_of_t |> b64_url_encode
  in
  given_signature = recomputed_signature

let verify_and_decode ~algorithm token_string =
  try
    let token = Jwt.t_of_token token_string in
    let is_valid = verify ~algorithm token in
    match is_valid with
    | true -> Payload (Jwt.payload_of_t token)
    | false -> SignatureMismatch
  with Jwt.Bad_token -> FormatError
