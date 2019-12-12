open Codegen
open Core

(* TODO - add tests *)

(** Given a list of resource attributes, return a string "column_name1, column_name2, ..."
 *
 * Note the lack of parentheses. *)
let sql_comma_string resource_attributes =
  let sql_names = List.map resource_attributes ~f:(fun a -> a.sql_name) in
  String.concat ~sep:", " sql_names

(** Given a list of resource attributes, return a string "(column_name1, column_name2, ...)"
 * This accounts for Caqti tuples becoming nested above a length of four. *)
let caqti_tuple_name_string resource_attributes =
  let names = List.map resource_attributes ~f:(fun a -> a.name) in
  let length = List.length resource_attributes in
  match length <= 4 with
  | true -> "(" ^ String.concat ~sep:", " names ^ ")"
  | false ->
      let f name acc = Printf.sprintf "(%s, %s)" name acc in
      List.fold_right ~f ~init:(List.last_exn names)
        (List.take names (length - 1))

(** Map OCaml type names to Caqti ones, mostly they are they same but differ e.g. for options. *)
let type_name_to_caqti_type_name type_name =
  match type_name with
  | "int" | "bool" | "string" -> type_name
  | "int option" | "bool option" | "string option" ->
      let inner_type, _ = String.lsplit2_exn ~on:' ' type_name in
      "option\n    " ^ inner_type
  | _ -> failwith "Unexpected type name"

(** Given a list of resource attributes, return a string "(tup[n] type1 type2 ...)". *)
let caqti_tuple_type_string resource_attributes =
  let length = List.length resource_attributes in
  let sep, inital_string =
    match length <= 4 with
    (* TODO - check length = 1 case *)
    | true -> (
        match length = 1 with
        | true -> ("", "")
        | false -> (" ", Printf.sprintf "tup%d" length) )
    | false -> (" & ", "let (&) = tup2 in")
  in
  let joined_types =
    String.concat ~sep
      (List.map resource_attributes ~f:(fun a ->
           type_name_to_caqti_type_name a.type_name))
  in
  Printf.sprintf "(%s %s)" inital_string joined_types

(** Generate the code to create the table for a resource. *)
let generate_create_table_sql table_name resource_attributes =
  let column_definitions =
    List.map resource_attributes ~f:(fun a ->
        a.sql_name ^ " " ^ a.sql_type_name)
  in
  let body = String.concat ~sep:",\n" column_definitions in
  Printf.sprintf {sql| CREATE TABLE %s (
%s
       )
    |sql} table_name
    (Utils.indent body ~filler:' ' ~amount:9)

(** Generate migrations code. *)
let make_migration_code table_name resource_attributes =
  let query = generate_create_table_sql table_name resource_attributes in
  Printf.sprintf
    {ocaml|let migrate_query =
  Caqti_request.exec Caqti_type.unit
   {sql|%s|sql}

let migrate (module Db : Caqti_lwt.CONNECTION) = Db.exec migrate_query ()

let rollback_query = Caqti_request.exec Caqti_type.unit {sql| DROP TABLE %s |sql}

let rollback (module Db : Caqti_lwt.CONNECTION) = Db.exec rollback_query ()|ocaml}
    query table_name

(** Generate model code for getting all instances of a resource. *)
let make_all_code table_name resource_attributes =
  Printf.sprintf
    {ocaml|let all_query =
  Caqti_request.collect Caqti_type.unit
    Caqti_type.%s
    {sql| SELECT %s FROM %s |sql}

let all (module Db : Caqti_lwt.CONNECTION) =
  let result =
    Db.fold all_query
      (fun %s acc -> {%s} :: acc)
      () []
  in
  Ocoi.Db.handle_caqti_result result|ocaml}
    (caqti_tuple_type_string resource_attributes)
    (sql_comma_string resource_attributes)
    table_name
    (caqti_tuple_name_string resource_attributes)
    (record_names_string resource_attributes "; ")

(** Generate model code for getting a resource instance by ID. *)
let make_show_code table_name resource_attributes =
  Printf.sprintf
    {ocaml|let show_query =
  Caqti_request.find_opt Caqti_type.int
    Caqti_type.%s
    {sql| SELECT %s
          FROM %s
          WHERE id = (?)
    |sql}

let show (module Db : Caqti_lwt.CONNECTION) id =
  let result = Db.find_opt show_query id in
  let%%lwt data = Ocoi.Db.handle_caqti_result result in
  let record = Option.map ~f:(fun %s -> {%s}) data in
  Lwt.return record|ocaml}
    (caqti_tuple_type_string resource_attributes)
    (sql_comma_string resource_attributes)
    table_name
    (caqti_tuple_name_string resource_attributes)
    (record_names_string resource_attributes "; ")

(** Generate model code for creating a resource instance. *)
let make_create_code table_name resource_attributes =
  Printf.sprintf
    {ocaml|let create_query =
  Caqti_request.find
    Caqti_type.%s
    Caqti_type.int
    {sql| INSERT INTO %s (%s) VALUES (%s) RETURNING id |sql}

let create (module Db : Caqti_lwt.CONNECTION) %s =
  let result = Db.find create_query %s in
  Ocoi.Db.handle_caqti_result result|ocaml}
    (caqti_tuple_type_string (without_id resource_attributes))
    table_name
    (sql_comma_string (without_id resource_attributes))
    (String.concat ~sep:", "
       (List.map (without_id resource_attributes) ~f:(fun _ -> "?")))
    (ocaml_parameters_string (without_id resource_attributes))
    (caqti_tuple_name_string (without_id resource_attributes))

(** Generate model code for updating resource instance. *)
let make_update_code table_name resource_attributes =
  let reordered =
    without_id resource_attributes @ [ get_id_attribute resource_attributes ]
  in
  Printf.sprintf
    {ocaml|let update_query =
  Caqti_request.exec
    Caqti_type.%s
    {sql| UPDATE %s
       SET (%s) = (%s)
       WHERE id = (?)
    |sql}

let update (module Db : Caqti_lwt.CONNECTION) {%s} =
  let result = Db.exec update_query %s in
  Ocoi.Db.handle_caqti_result result|ocaml}
    (caqti_tuple_type_string reordered)
    table_name
    (sql_comma_string (without_id resource_attributes))
    (String.concat ~sep:", "
       (List.map (without_id resource_attributes) ~f:(fun _ -> "?")))
    (record_names_string resource_attributes "; ")
    (caqti_tuple_name_string reordered)

(** Generate model code for destroying a resource instance. *)
let make_destroy_code table_name =
  Printf.sprintf
    {ocaml|let destroy_query =
  Caqti_request.exec Caqti_type.int {sql| DELETE FROM %s WHERE id = (?) |sql}

let destroy (module Db : Caqti_lwt.CONNECTION) id =
  let result = Db.exec destroy_query id in
  Ocoi.Db.handle_caqti_result result|ocaml}
    table_name

let write_queries ~model_path ~tree =
  let module_name, dir = module_name_and_dir ~model_path in
  let queries_path =
    let ( / ) = Filename.concat in
    dir / ".." / "queries" / (module_name ^ ".ml")
  in
  let oc = Out_channel.create queries_path in
  let resource_attributes =
    tree |> get_t_node_labels_ast |> get_resource_attributes
  in
  let table_name = Utils.pluralize module_name in
  let queries =
    [
      make_all_code table_name resource_attributes;
      make_show_code table_name resource_attributes;
      make_create_code table_name resource_attributes;
      make_update_code table_name resource_attributes;
      make_destroy_code table_name;
    ]
  in
  let module_open_statement =
    "open Core\nopen Models." ^ String.capitalize module_name
  in
  let crud_queries =
    String.concat ~sep:"\n\n" (module_open_statement :: queries)
  in
  let migration_queries = make_migration_code table_name resource_attributes in
  Printf.fprintf oc "%s\n%s\n" crud_queries migration_queries;
  Out_channel.close oc
