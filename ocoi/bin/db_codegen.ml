open Codegen
open Core

(** Given a list of resource attributes, return a string "column_name1, column_name2, ..."
 * (note the lack of parentheses). *)
let column_tuple_string resource_attributes =
  let joined_names =
    String.concat ~sep:", "
      (List.map resource_attributes ~f:(fun a -> a.sql_name))
  in
  joined_names

(** Given a list of resource attributes, return a string "(tup[n] type1 type2 ...)". *)
let caqti_tuple_type_string resource_attributes =
  let length = List.length resource_attributes in
  let sep, inital_string =
    match length <= 4 with
    | true -> (" ", Printf.sprintf "tup%d" length)
    | false -> (" & ", "let (&) = tup2 in")
  in
  let joined_types =
    String.concat ~sep (List.map resource_attributes ~f:(fun a -> a.type_name))
  in
  Printf.sprintf "(%s %s)" inital_string joined_types

(** Generate the code to create the table for a resource. *)
let generate_create_table_sql table_name resource_attributes =
  let column_definitions =
    List.map resource_attributes ~f:(fun a ->
        a.sql_name ^ " " ^ a.sql_type_name)
  in
  let body = String.concat ~sep:",\n" column_definitions in
  Printf.sprintf {sql|CREATE TABLE %s (
         %s
         )
    |sql}
    table_name body

(** Generate migrations code. *)
let make_migration_code table_name resource_attributes =
  let query = generate_create_table_sql table_name resource_attributes in
  (* TODO - make generated SQL indented nicely *)
  Printf.sprintf
    {ocaml|let migrate_query =
  Caqti_request.exec Caqti_type.unit
   {|%s|}

let migrate (module Db : Caqti_lwt.CONNECTION) = Db.exec migrate_query ()

let rollback_query = Caqti_request.exec Caqti_type.unit {| DROP TABLE %s |}

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
      (fun (%s) acc -> {%s} :: acc)
      () []
  in
  Ocoi.Db.handle_caqti_result result|ocaml}
    (caqti_tuple_type_string resource_attributes)
    (column_tuple_string resource_attributes)
    table_name
    (record_names_string resource_attributes ", ")
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
  let record =
    match data with
    | Some (%s) -> Some {%s}
    | None -> None
  in
  Lwt.return record|ocaml}
    (caqti_tuple_type_string resource_attributes)
    (column_tuple_string resource_attributes)
    table_name
    (record_names_string resource_attributes ", ")
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
  let result = Db.find create_query (%s) in
  Ocoi.Db.handle_caqti_result result|ocaml}
    (caqti_tuple_type_string (without_id resource_attributes))
    table_name
    (column_tuple_string (without_id resource_attributes))
    (String.concat ~sep:", "
       (List.map (without_id resource_attributes) ~f:(fun _ -> "?")))
    (parameters_string (without_id resource_attributes))
    (record_names_string (without_id resource_attributes) ", ")

(** Generate model code for updating resource instance. *)
let make_update_code table_name resource_attributes =
  Printf.sprintf
    {ocaml|let update_query =
  Caqti_request.exec
    Caqti_type.%s
    {| UPDATE %s
       SET (%s) = (%s)
       WHERE id = (?)
    |}

let update (module Db : Caqti_lwt.CONNECTION) {%s} =
  let result = Db.exec update_query (%s, id) in
  Ocoi.Db.handle_caqti_result result|ocaml}
    (caqti_tuple_type_string
       (without_id resource_attributes @ [get_id_attribute resource_attributes]))
    table_name
    (column_tuple_string (without_id resource_attributes))
    (String.concat ~sep:", "
       (List.map (without_id resource_attributes) ~f:(fun _ -> "?")))
    (record_names_string resource_attributes "; ")
    (record_names_string (without_id resource_attributes) ", ")

(** Generate model code for destroying a resource instance. *)
let make_destroy_code table_name =
  Printf.sprintf
    {ocaml|let destroy_query =
  Caqti_request.exec Caqti_type.int {sql| DELETE FROM %s WHERE id = (?) |sql}

let destroy (module Db : Caqti_lwt.CONNECTION) id =
  let result = Db.exec destroy_query id in
  Ocoi.Db.handle_caqti_result result|ocaml}
    table_name

let make_migration_or_rollback_script module_name operation =
  Printf.sprintf
    {ocaml|let%%lwt conn = Db.connection

let result = Lwt_main.run (Queries.%s.%s conn)

let () =
  match result with
  | Ok () -> print_endline "%s successful."
  | Error err ->
      print_endline "%s failed!" ;
      failwith (Caqti_error.show err)|ocaml}
    (String.capitalize module_name)
    (* TODO - either migrate or rollback *)
    operation operation

(* TODO - factor getting queries_name etc. out *)
let write_migration_script name script_suffix operation =
  let open Filename in
  let module_name = name |> chop_extension |> basename in
  let queries_name =
    concat (dirname name)
      ("../db/migrate/" ^ module_name ^ script_suffix ^ ".ml")
  in
  let script_content =
    make_migration_or_rollback_script module_name operation
  in
  let oc = Out_channel.create queries_name in
  Printf.fprintf oc "%s\n" script_content ;
  Out_channel.close oc

module Suffixes = struct
  let migrate = "_migrate"

  let rollback = "_rollback"
end

let write_new_migrations_dune ~module_name ~dune_path =
  let dune_content =
    Printf.sprintf
      {dune|(executables
(names %s %s)
(libraries models db)
(preprocess (pps lwt_ppx)))|dune}
      (module_name ^ Suffixes.migrate)
      (module_name ^ Suffixes.rollback)
  in
  let oc = Out_channel.create dune_path in
  Printf.fprintf oc "%s\n" dune_content ;
  Out_channel.close oc

let update_migrations_dune ~module_name ~dune_path =
  let dune_lines = In_channel.read_lines dune_path in
  (* Should be "(names model1_migrate model1_rollback ...)" *)
  let names_line = List.nth_exn dune_lines 1 in
  let chopped = String.chop_suffix_exn names_line ~suffix:")" in
  let new_names_line =
    String.concat
      [ chopped;
        module_name ^ Suffixes.migrate;
        " ";
        module_name ^ Suffixes.rollback;
        ")" ]
  in
  let new_lines =
    List.hd_exn dune_lines :: new_names_line :: List.slice dune_lines 2 0
  in
  let dune_content = String.concat ~sep:"\n" new_lines in
  let oc = Out_channel.create dune_path in
  Printf.fprintf oc "%s\n" dune_content ;
  Out_channel.close oc

let create_or_update_migrate_dune name =
  let module_name = Filename.(name |> chop_extension |> basename) in
  let dune_path = Filename.(concat (dirname name) "../db/migrate/dune") in
  match Sys.file_exists dune_path with
  | `Yes -> update_migrations_dune ~module_name ~dune_path
  | `No -> write_new_migrations_dune ~module_name ~dune_path
  | `Unknown -> failwith "Migrations dune file has unknown status"

let write_migration_scripts name =
  write_migration_script name Suffixes.migrate "Migration" ;
  write_migration_script name Suffixes.rollback "Rollback" ;
  create_or_update_migrate_dune name

let write_crud_queries name tree =
  let open Filename in
  let queries_name = concat (dirname name) ("../queries/" ^ basename name) in
  let oc = Out_channel.create queries_name in
  let module_name = name |> chop_extension |> basename in
  let resource_attributes =
    tree |> get_t_node_labels_ast |> get_resource_attributes
  in
  let queries =
    [ make_all_code module_name resource_attributes;
      make_show_code module_name resource_attributes;
      make_create_code module_name resource_attributes;
      make_update_code module_name resource_attributes;
      make_destroy_code module_name ]
  in
  let module_open_statement = "open Models." ^ String.capitalize module_name in
  let crud_queries_string =
    String.concat ~sep:"\n\n" (module_open_statement :: queries)
  in
  let migration_queries =
    make_migration_code module_name resource_attributes
  in
  Printf.fprintf oc "%s\n%s\n" crud_queries_string migration_queries ;
  Out_channel.close oc
