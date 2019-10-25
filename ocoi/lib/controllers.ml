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

let create_handler name create =
  post name (fun req ->
      let%lwt json = App.json_of_body_exn req in
      let%lwt id = create json in
      Handler_utils.empty_created_response (name ^ Printf.sprintf "/%d" id))

let index_handler name index to_yojson =
  get name (fun _ ->
      let%lwt resources = index () in
      let resources_json = List.map resources ~f:to_yojson in
      `Json (`List resources_json) |> respond')

let show_handler name show to_yojson =
  get (id_path name) (fun req ->
      let%lwt resource_opt = show (int_of_string (param req "id")) in
      match resource_opt with
      | Some resource -> `Json (resource |> to_yojson) |> respond'
      | None -> `String "" |> respond' ~code:`Not_found)

let update_handler name update of_yojson =
  put name (fun req ->
      let%lwt json = App.json_of_body_exn req in
      let resource_err = of_yojson json in
      match resource_err with
      | Ok resource ->
          let%lwt () = update resource in
          empty_response `No_content
      (* TODO - make error message nicer *)
      | Error err ->
          respond_bad_request_400 ("(At least one) bad field: " ^ err))

let destroy_handler name destroy =
  delete (id_path name) (fun req ->
      let%lwt () = destroy (int_of_string (param req "id")) in
      empty_response `No_content)

let register_crud name (module Crud : Crud) app =
  let open Crud in
  app |> create_handler name create
  |> show_handler name show to_yojson
  |> update_handler name update of_yojson
  |> destroy_handler name destroy
  |> index_handler name index to_yojson
