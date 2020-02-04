open Base
open Opium.Std
open Ocoi_api

module Make = struct
  module Json (Parameters : Parameters.Json) = struct
    let f req =
      (* TODO catch Yojson.Json_error here (and maybe more?) *)
      let%lwt json = App.json_of_body_exn req in
      let j =
        match json |> Parameters.t_of_yojson' with
        | Ok x -> x
        | Error _ -> failwith "erro"
      in
      j |> Lwt.return
  end

  module Json_jwt (Parameters : Parameters.Jwt_json) = struct
    let f ~algorithm req =
      let%lwt json = App.json_of_body_exn req in
      let j =
        match json |> Parameters.parameters_of_yojson' with
        | Ok x -> x
        | Error _ -> failwith "erro"
      in
      let jwt =
        let token_opt = Auth.get_token req in
        let open Option in
        match
          token_opt >>| fun token ->
          Jwt_utils.verify_and_decode ~algorithm token
        with
        | Some (Payload p) -> p
        | _ -> failwith "erro"
      in
      (j, jwt) |> Lwt.return
  end

  module None (Parameters : Parameters.None) = struct
    let f _req = () |> Lwt.return
  end

  module One_param (Parameters : Parameters.One_param) (S : Specification.S) =
  struct
    let () = assert (String.count ~f:(Char.( = ) ':') S.path = 1)

    let name =
      (* Find the only occurrence of [:some_var] in the path *)
      let pattern = Str.regexp {re|.*:\([^/]*\)\(/\|$\)|re} in
      let () = assert (Str.string_match pattern S.path 0) in
      Str.matched_group 1 S.path

    let f req = Parameters.of_string (param req name) |> Lwt.return
  end

  module Custom (Parameters : Parameters.Custom) = struct
    let f req = Parameters.f req |> Lwt.return
  end
end
