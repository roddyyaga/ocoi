open Core
open Ocoi_api

type jwt_error =
  [ `Signature_mismatch | `Format_error | `Absent | `No_expiry | `Expired ]

type json_error = [ `Parsing of string | `Conversion of exn * Yojson.Safe.t ]

type error = [ `Jwt of jwt_error | `Json of json_error ]

let get_jwt ?(require_expiry = true) req ~jwk =
  let token_opt = Auth.get_token req in
  let ( let* ) = Result.( >>= ) in
  let* payload =
    match
      Option.(token_opt >>| fun token -> Jwt_utils.verify_and_decode ~jwk token)
    with
    | Some (Ok p) -> Ok p
    | Some (Error e) -> Error (`Jwt e)
    | None -> Error (`Jwt `Absent)
  in
  if not require_expiry then Ok payload
  else
    match Jwt_utils.(get_claim "exp" payload) with
    | None -> Error (`Jwt `No_expiry)
    | Some _expiry -> Ok payload

(* Expiry time already checked by Jose *)

let try_with_json_error f =
  try f () with
  | Yojson.Json_error message -> Error (`Json (`Parsing message)) |> Lwt.return
  | Ppx_yojson_conv_lib.Yojson_conv.Of_yojson_error (e, yojson) ->
      Error (`Json (`Conversion (e, yojson))) |> Lwt.return

module Make = struct
  module None (Parameters : Parameters.None) = struct
    let f _req = () |> Lwt_result.return
  end

  module Json = struct
    module Only (Parameters : Parameters.Json) = struct
      let f req =
        try_with_json_error (fun () ->
            let%lwt json = Opium.Request.to_json_exn req in
            Ok (Parameters.t_of_yojson json) |> Lwt.return)
    end

    module Jwt (Parameters : Parameters.Json.Jwt) = struct
      let f ?(require_expiry = true) ~jwk req =
        try_with_json_error (fun () ->
            let%lwt json = Opium.Request.to_json_exn req in
            let caml_of_json = json |> Parameters.parameters_of_yojson in
            let jwt_result = get_jwt ~require_expiry req ~jwk in
            match jwt_result with
            | Ok jwt -> (caml_of_json, jwt) |> Lwt_result.return
            | Error _ as error -> error |> Lwt.return)
    end
  end

  module Path = struct
    let get_one_param_name (module S : Specification.S) =
      let () = assert (String.count ~f:(Char.( = ) ':') S.path = 1) in
      (* Find the only occurrence of [:some_var] in the path *)
      let pattern = Str.regexp {re|.*:\([^/]*\)\(/\|$\)|re} in
      let () = assert (Str.string_match pattern S.path 0) in
      Str.matched_group 1 S.path

    module One = struct
      module Only (Parameters : Parameters.Path.One) (S : Specification.S) =
      struct
        let name = get_one_param_name (module S)

        let f req =
          Parameters.of_string (Opium.Router.param req name)
          |> Lwt_result.return
      end

      module Query
          (Parameters : Parameters.Path.One.Query)
          (S : Specification.S) =
      struct
        let name = get_one_param_name (module S)

        let f req =
          let path_parameter_value =
            Parameters.path_of_string (Opium.Router.param req name)
          in
          let query_parameter_values =
            List.map
              ~f:(Uri.get_query_param (Uri.of_string req.target))
              Parameters.query_fields
          in
          (path_parameter_value, query_parameter_values) |> Lwt_result.return
      end

      module Jwt (Parameters : Parameters.Path.One.Jwt) (S : Specification.S) =
      struct
        let name = get_one_param_name (module S)

        let f ?(require_expiry = true) ~jwk req =
          let jwt_result = get_jwt ~require_expiry ~jwk req in
          match jwt_result with
          | Ok jwt ->
              let param_value =
                Parameters.of_string (Opium.Router.param req name)
              in
              (param_value, jwt) |> Lwt_result.return
          | Error _ as error -> error |> Lwt.return
      end
    end
  end

  module Jwt (Parameters : Parameters.Jwt) = struct
    let f ?(require_expiry = true) ~jwk req =
      get_jwt ~require_expiry ~jwk req |> Lwt.return
  end

  module Custom (Parameters : Parameters.Custom) = struct
    let f req = Parameters.f req |> Lwt_result.return
  end
end
