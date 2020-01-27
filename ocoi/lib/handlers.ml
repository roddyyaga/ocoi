open Core
open Opium.Std

let json_to_json (verb : Opium.App.route) (path : string) f =
  verb path (fun req ->
      let%lwt json = App.json_of_body_exn req in
      let%lwt response_content = f json in
      `Json response_content |> respond')

let jwt_to_json (verb : Opium.App.route) (path : string) f ?auth_getter
    ~algorithm =
  verb path (fun req ->
      let token = Auth.get_token ?auth_getter req in
      match token with
      | Some token -> (
          let decoded = Jwt_utils.verify_and_decode ~algorithm token in
          match decoded with
          | Jwt_utils.Payload payload ->
              let%lwt response_content = f req payload in
              `Json response_content |> respond'
          | Jwt_utils.SignatureMismatch | Jwt_utils.FormatError ->
              Handler_utils.empty_response `Unauthorized )
      | None -> Handler_utils.empty_response `Unauthorized)

let jwt_only_to_json verb path f ?auth_getter ~algorithm =
  let inner _ payload = f payload in
  jwt_to_json verb path ?auth_getter ~algorithm inner

let jwt_json_to_json verb path f ?auth_getter ~algorithm =
  let inner req payload =
    let%lwt json = App.json_of_body_exn req in
    f payload json
  in
  jwt_to_json verb path ?auth_getter ~algorithm inner
