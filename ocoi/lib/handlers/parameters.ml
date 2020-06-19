open Base
open Opium.Std
open Ocoi_api

let get_jwt req ~algorithm =
  let token_opt = Auth.get_token req in
  let open Option in
  match
    token_opt >>| fun token -> Jwt_utils.verify_and_decode ~algorithm token
  with
  | Some (Payload p) -> p
  | Some SignatureMismatch -> failwith "Signature mismatch"
  | Some FormatError -> failwith "Format error"
  | None -> failwith "No JWT token"

module Make = struct
  module None (Parameters : Parameters.None) = struct
    let f _req = () |> Lwt.return
  end

  module Json = struct
    module Only (Parameters : Parameters.Json) = struct
      let f req =
        (* TODO catch Yojson.Json_error here (and maybe more?) *)
        let%lwt json = App.json_of_body_exn req in
        match json |> Parameters.t_of_yojson' with
        | Ok x -> x |> Lwt.return
        | Error _ -> failwith "Error parsing JSON"
    end

    module Jwt (Parameters : Parameters.Json.Jwt) = struct
      let f ~algorithm req =
        let%lwt json = App.json_of_body_exn req in
        let j =
          match json |> Parameters.parameters_of_yojson' with
          | Ok x -> x
          | Error _ -> failwith "Error decoding JSON"
        in
        let jwt =
          let token_opt = Auth.get_token req in
          let open Option in
          match
            token_opt >>| fun token ->
            Jwt_utils.verify_and_decode ~algorithm token
          with
          | Some (Payload p) -> p
          | Some SignatureMismatch -> failwith "Signature mismatch"
          | Some FormatError -> failwith "Format error"
          | None -> failwith "No JWT token"
        in
        (j, jwt) |> Lwt.return
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

        let f req = Parameters.of_string (param req name) |> Lwt.return
      end

      module Query
          (Parameters : Parameters.Path.One.Query)
          (S : Specification.S) =
      struct
        let name = get_one_param_name (module S)

        let f req =
          let path_parameter_value =
            Parameters.path_of_string (param req name)
          in
          let query_parameter_values =
            List.map
              ~f:(Uri.get_query_param (Uri.of_string req.Request.target))
              Parameters.query_fields
          in
          (path_parameter_value, query_parameter_values) |> Lwt.return
      end

      module Jwt (Parameters : Parameters.Path.One.Jwt) (S : Specification.S) =
      struct
        let name = get_one_param_name (module S)

        let f ~algorithm req =
          let jwt = get_jwt ~algorithm req in
          let param_value = Parameters.of_string (param req name) in
          (param_value, jwt) |> Lwt.return
      end
    end
  end

  module Jwt (Parameters : Parameters.Jwt) = struct
    let f ~algorithm req = get_jwt ~algorithm req |> Lwt.return
  end

  module Custom (Parameters : Parameters.Custom) = struct
    let f req = Parameters.f req |> Lwt.return
  end
end
