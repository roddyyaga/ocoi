open Core
open Opium.Std
open Handler_utils

module type Crud = sig
  type t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val create : Yojson.Safe.t -> int Lwt.t

  val index : unit -> t list Lwt.t

  val show : int -> t option Lwt.t

  val update : t -> unit Lwt.t

  val destroy : int -> unit Lwt.t
end

(** Utility to make defining wrapped handler creators easier. *)
let wrap wrapper (verb : Opium.App.route) path
    (request_fun : Request.t -> Response.t Lwt.t) =
  match wrapper with
  | Some f -> verb path (f request_fun)
  | None -> verb path request_fun

let create_request_fun name create req =
  let%lwt json = App.json_of_body_exn req in
  let%lwt id = create json in
  Handler_utils.empty_created_response (name ^ Printf.sprintf "/%d" id)

let create_handler name create ?wrapper =
  wrap wrapper post name (create_request_fun name create)

let index_request_fun index to_yojson _ =
  let%lwt resources = index () in
  let resources_json = List.map resources ~f:to_yojson in
  `Json (`List resources_json) |> respond'

let index_handler name index to_yojson ?wrapper =
  wrap wrapper get name (index_request_fun index to_yojson)

let show_request_fun show to_yojson req =
  let%lwt resource_opt = show (int_of_string (param req "id")) in
  match resource_opt with
  | Some resource -> `Json (resource |> to_yojson) |> respond'
  | None -> `String "" |> respond' ~code:`Not_found

let show_handler name show to_yojson ?wrapper =
  wrap wrapper get (id_path name) (show_request_fun show to_yojson)

let update_request_fun update of_yojson req =
  let%lwt json = App.json_of_body_exn req in
  let resource_err = of_yojson json in
  match resource_err with
  | Ok resource ->
      let%lwt () = update resource in
      empty_response `No_content
  (* TODO - make error message nicer *)
  | Error err -> respond_bad_request_400 ("(At least one) bad field: " ^ err)

let update_handler name update of_yojson ?wrapper =
  wrap wrapper put name (update_request_fun update of_yojson)

let destroy_request_fun destroy req =
  let%lwt () = destroy (int_of_string (param req "id")) in
  empty_response `No_content

let destroy_handler name destroy ?wrapper =
  wrap wrapper delete (id_path name) (destroy_request_fun destroy)

let register_crud name (module Crud : Crud) app =
  let open Crud in
  app |> create_handler name create
  |> show_handler name show to_yojson
  |> update_handler name update of_yojson
  |> destroy_handler name destroy
  |> index_handler name index to_yojson
