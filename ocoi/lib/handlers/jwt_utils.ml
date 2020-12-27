open Base

let make_token ~jwk claims =
  let header = Jose.Header.make_header ~typ:"JWT" jwk in
  let payload =
    let open Jose.Jwt in
    List.fold ~init:empty_payload
      ~f:(fun payload (key, value) -> payload |> add_claim key (`String value))
      claims
  in
  Jose.Jwt.sign ~header ~payload jwk |> function
  | Ok t -> t
  | Error (`Msg m) -> failwith m

let make_and_encode ~jwk claims = make_token ~jwk claims |> Jose.Jwt.to_string

let verify_and_decode ~jwk token_string =
  let open Result.Monad_infix in
  Jose.Jwt.of_string token_string >>= Jose.Jwt.validate ~jwk >>| fun token ->
  token.payload

let get_claim claim payload =
  Yojson.Safe.Util.(payload |> member claim |> to_string_option)
