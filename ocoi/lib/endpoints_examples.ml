open Core
open Endpoints

module Example = struct
  module Specification = struct
    let verb = Get

    let path = "/example"

    module Parameters = struct
      type t = { teachers_name: string; childhood_pet: string }
      [@@deriving yojson]
    end

    module Responses = struct
      type t = { id: int; stripper_name: string } [@@deriving yojson]
    end
  end

  module Implementation = struct
    open Specification.Parameters
    open Specification.Responses

    let f { teachers_name; childhood_pet } =
      { id = 1; stripper_name = teachers_name ^ childhood_pet } |> Lwt.return
  end
end

module Example2 = struct
  module Specification = struct
    let verb = Get

    let path = "/example"

    module Parameters = struct
      type t = { teachers_name: string; childhood_pet: string }
      [@@deriving yojson]
    end

    module Responses = struct
      type ok = { id: int; stripper_name: string } [@@deriving yojson]

      type error = { message: string } [@@deriving yojson]

      type t = [ `_200 of ok | `_500 of error ] [@@deriving yojson]
    end
  end

  module Implementation = struct
    open Specification.Parameters
    open Specification.Responses

    let f { teachers_name; childhood_pet } =
      match teachers_name with
      | "cool" ->
          `_200 { id = 1; stripper_name = teachers_name ^ childhood_pet }
          |> Lwt.return
      | _ -> `_500 { message = "uncool teachers name!" } |> Lwt.return
  end
end

module Example3 = struct
  module Specification = struct
    let verb = Post

    let path = "/example3"

    module Parameters = struct
      type parameters = { teachers_name: string; childhood_pet: string }
      [@@deriving yojson]

      type t = parameters * Jwt.payload
    end

    module Responses = struct
      type ok = { id: int; friend_name: string } [@@deriving yojson]

      type error = { message: string } [@@deriving yojson]

      type t = [ `_200 of ok | `_500 of error ] [@@deriving yojson]
    end
  end

  module Implementation = struct
    open Specification.Parameters
    open Specification.Responses

    let f ({ teachers_name; childhood_pet }, payload) =
      match
        Option.mem
          (Jwt_utils.get_claim "sub" payload)
          teachers_name ~equal:String.( = )
      with
      | true -> (
          match teachers_name with
          | "cool" ->
              `_200 { id = 1; friend_name = teachers_name ^ childhood_pet }
              |> Lwt.return
          | _ -> `_500 { message = "uncool teachers name!" } |> Lwt.return )
      | false -> `_500 { message = "permission denied!" } |> Lwt.return
  end
end

let handlers =
  let g =
    let open Example.Specification in
    let module M =
      Handler
        (Example.Specification)
        (Make.Parameters.Json (Parameters))
        (Make.Responses.Json (Responses))
        (Example.Implementation)
    in
    M.f
  in

  let h ~algorithm =
    let open Example3.Specification in
    let module P = Make.Parameters.Json_jwt (Parameters) in
    let module R = Make.Responses.Json (Responses) in
    handler
      (module Example3.Specification)
      (P.f ~algorithm) Example3.Implementation.f R.f
  in
  [ g; h ~algorithm:(Jwt.HS256 "sekret key") ]
