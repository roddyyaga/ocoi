open Core
open Opium.Std

module type Endpoint = sig
  module Spec : sig
    val verb : string

    val path : string

    module Parameters : sig
      type t
    end

    module Responses : sig
      type t
    end
  end

  module Implementation : sig
    val f : Spec.Parameters.t -> Spec.Responses.t Lwt.t
  end
end

module type Jwt_json_params = sig
  type json

  val json_of_yojson :
    Yojson.Safe.t -> json Ppx_deriving_yojson_runtime.error_or

  type t = json * int
end

module type Json_responses = sig
  type t

  val to_yojson : t -> Yojson.Safe.t
end

module type Json_jwt_make_in_sig = functor (J : Jwt_json_params) -> sig
  val f : Request.t -> (J.json * int) Lwt.t
end

module Make_in = struct
  module Jwt_json (J : Jwt_json_params) = struct
    let f req =
      let%lwt json = App.json_of_body_exn req in
      let j =
        match json |> J.json_of_yojson with
        | Ok x -> x
        | Error _ -> failwith "erro"
      in
      (j, 7) |> Lwt.return
  end
end

module Make_out = struct
  module Json (J : Json_responses) = struct
    let f response_lwt =
      let%lwt response = response_lwt in
      response |> J.to_yojson |> Lwt.return
  end
end

module type Jwt_json_endpoint = sig
  module Spec : sig
    val verb : string

    val path : string

    module Parameters : Jwt_json_params

    module Responses : Json_responses
  end

  module Implementation : sig
    val f : Spec.Parameters.t -> Spec.Responses.t Lwt.t
  end
end

module type Boi = sig
  module type Endpoint = Endpoint

  module In_maker (E : Endpoint) (B : Jwt_json_endpoint) : sig end

  module Out_maker = Make_out.Json
end

module Jwt_json_boi = struct
  module type Endpoint = Jwt_json_endpoint

  module In_maker = Make_in.Jwt_json
  module Out_maker = Make_out.Json
end

module Login = struct
  module Spec = struct
    let verb = "post"

    let path = "/users/login"

    module Parameters = struct
      type inner = { email: string; password: string } [@@deriving yojson]

      type json = { user: inner } [@@deriving yojson]

      type t = json * int
    end

    module Responses = struct
      type ok_inner = {
        email: string;
        token: string;
        username: string;
        bio: string option;
        image: string option;
      }
      [@@deriving yojson]

      type _200 = { user: ok_inner } [@@deriving yojson]

      type _401 = unit [@@deriving yojson]

      type error_inner = { body: string list } [@@deriving yojson]

      type _422 = { errors: error_inner } [@@deriving yojson]

      type t = [ `C200 of _200 | `C401 of _401 | `C422 of _422 ]
      [@@deriving yojson]
    end
  end

  module Implementation = struct
    let f (Spec.Parameters.{ user = { email; password } }, _) =
      match password with
      | "blahh" ->
          let open Spec.Responses in
          `C200
            {
              user =
                { email; token = ""; username = ""; bio = None; image = None };
            }
          |> Lwt.return
      | _ -> `C401 () |> Lwt.return
  end
end

module Input = Make_in.Jwt_json (Login.Spec.Parameters)
module Output = Make_out.Json (Login.Spec.Responses)

let controller in_t =
  let open Login.Spec.Parameters in
  let%lwt { user = { email; password } }, n = in_t in
  match n with
  | 7 -> `C401 () |> Lwt.return
  | _ ->
      let open Login.Spec.Responses in
      `C200
        {
          user =
            {
              email;
              token = password;
              username = password;
              bio = None;
              image = None;
            };
        }
      |> Lwt.return

let reg_jwt_json_gen (module E : Jwt_json_boi.Endpoint) =
  let module Input = Jwt_json_boi.In_maker (E.Spec.Parameters) in
  let module Output = Jwt_json_boi.Out_maker (E.Spec.Responses) in
  let impl req =
    let%lwt x = req |> Input.f in
    let y = x |> E.Implementation.f in
    let z = y |> Output.f in
    z
  in
  impl

let reg_jwt_json (module E : Jwt_json_endpoint) =
  let module Input = Make_in.Jwt_json (E.Spec.Parameters) in
  let module Output = Make_out.Json (E.Spec.Responses) in
  let impl req =
    let%lwt x = req |> Input.f in
    let y = x |> E.Implementation.f in
    let z = y |> Output.f in
    z
  in
  impl

let impl = reg_jwt_json (module Login)
