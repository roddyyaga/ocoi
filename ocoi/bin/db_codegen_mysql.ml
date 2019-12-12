open Codegen
open Core

(* TODO - add tests *)

(** Given a list of resource attributes, return a string "column_name1, column_name2, ..."
 * (note the lack of parentheses). *)
let column_tuple_string resource_attributes =
  let joined_names =
    String.concat ~sep:", "
      (List.map resource_attributes ~f:(fun a -> a.sql_name))
  in
  joined_names

(** Generate the code to create the table for a resource. *)
let generate_create_table_sql table_name resource_attributes =
  let column_definitions =
    List.map resource_attributes ~f:(fun a ->
        a.sql_name ^ " " ^ a.sql_type_name)
  in
  let body = String.concat ~sep:",\n" column_definitions in
  Printf.sprintf {|CREATE TABLE %s (
%s
       )
    |} table_name
    (Utils.indent body ~filler:' ' ~amount:9)

(** Generate migrations code. *)
let make_migration_code ~table_name ~resource_attributes =
  let query = generate_create_table_sql table_name resource_attributes in
  Printf.sprintf
    {ocaml|let migrate =
    [%%mysql
      execute
        {sql|
        %s
        |sql}]

let rollback =
    [%%mysql
      execute
        {sql| DROP TABLE %s |sql}]
|ocaml}
    query table_name

type ppx_mysql_parameter = Input | Output

(** Generates code like [%int{id}, %string{name}] *)
let ppx_mysql_parameters kind resource_attributes =
  let symbol = match kind with Input -> "%" | Output -> "@" in
  let f { type_name; sql_name; name; _ } =
    let relevant_name = match kind with Input -> name | Output -> sql_name in
    Printf.sprintf "%s%s{%s}" symbol type_name relevant_name
  in
  List.map ~f resource_attributes |> String.concat ~sep:", "

(** Generates code like [name = %string{name}, age = %int{age}] *)
let ppx_mysql_update_set resource_attributes =
  let f { sql_name; type_name; name; _ } =
    Printf.sprintf "%s = %%%s{%s}" sql_name type_name name
  in
  List.map ~f resource_attributes |> String.concat ~sep:", "

(** Generate code for getting all instances of a resource. *)
let make_all_code ~module_name ~table_name ~resource_attributes =
  Printf.sprintf
    {ocaml|let all dbh =
        [%%mysql
          select_all
            {sql|
            SELECT %s
            FROM %s
            |sql}] dbh
            >|= List.map %s_of_tuple
|ocaml}
    (ppx_mysql_parameters Output resource_attributes)
    table_name module_name

(** Generate model code for getting a resource instance by ID. *)
let make_show_code ~module_name ~table_name ~resource_attributes =
  Printf.sprintf
    {ocaml|let show dbh id =
  [%%mysql
    select_opt
      {sql|
      SELECT %s
      FROM %s
      WHERE id = %%int{id}
      |sql}]
  dbh ~id
  >|= %s_of_tuple
|ocaml}
    (ppx_mysql_parameters Output resource_attributes)
    table_name module_name

(** Generate model code for creating a resource instance. *)
let make_create_code ~table_name ~resource_attributes =
  Printf.sprintf
    {ocaml|let create dbh %s =
  [%%mysql
    select_one
      {sql|
      INSERT INTO %s (%s)
      VALUES (%s);
      SELECT LAST_INSERT_ID();
      |sql}] dbh %s
|ocaml}
    (ocaml_parameters_string (without_id resource_attributes))
    table_name
    (column_tuple_string (without_id resource_attributes))
    (ppx_mysql_parameters Input (without_id resource_attributes))
    (ocaml_parameters_string (without_id resource_attributes))

(** Generate model code for updating resource instance. *)
let make_update_code ~table_name ~resource_attributes =
  Printf.sprintf
    {ocaml|let update dbh {%s} =
  [%%mysql
    execute
      {sql|
      UPDATE %s
      SET %s
      WHERE id = %%int{id}
      |sql}]
      dbh %s
|ocaml}
    (record_names_string resource_attributes "; ")
    table_name
    (ppx_mysql_update_set resource_attributes)
    (ocaml_parameters_string resource_attributes)

(** Generate model code for destroying a resource instance. *)
let make_destroy_code ~table_name =
  Printf.sprintf
    {ocaml|let destroy dbh id =
  [%%mysql
    execute
      {sql| DELETE FROM %S WHERE id = %%int{id} |sql}]
  dbh ~id
|ocaml}
    table_name

let make_initial_code ~module_name ~resource_attributes =
  Printf.sprintf
    {ocaml|open Lwt_result.Infix;
open Models.%s;

    let %s_of_tuple (%s) = {%s}
|ocaml}
    (String.capitalize module_name)
    module_name
    (record_names_string resource_attributes ", ")
    (record_names_string resource_attributes "; ")

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
      make_all_code ~module_name ~table_name ~resource_attributes;
      make_show_code ~module_name ~table_name ~resource_attributes;
      make_create_code ~table_name ~resource_attributes;
      make_update_code ~table_name ~resource_attributes;
      make_destroy_code ~table_name;
    ]
  in
  let initial_code = make_initial_code ~module_name ~resource_attributes in
  let crud_queries = String.concat ~sep:"\n\n" (initial_code :: queries) in
  let migration_queries =
    make_migration_code ~table_name ~resource_attributes
  in
  Printf.fprintf oc "%s\n%s\n" crud_queries migration_queries;
  Out_channel.close oc
