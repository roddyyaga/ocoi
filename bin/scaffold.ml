open Asttypes
open Parsetree

let name = "test"

let tree =
  Pparse.parse_implementation Format.std_formatter ~tool_name:"ocamlc"
    (name ^ ".ml")

(** Return whether an AST node is of the form `type t = {...}`. *)
let is_valid_t_node {pstr_desc = desc; _} =
  match desc with
  | Pstr_type (_, declaration_list) -> (
    match declaration_list with
    | [{ptype_name; ptype_kind; _}] -> (
      match (ptype_name.txt, ptype_kind) with
      | "t", Ptype_record _ -> true
      | _ -> false )
    | _ -> false )
  | _ -> false

(** Find a unique node of the form `type t = {...}` in an AST tree and return its labels. *)
let get_t_node_labels_ast tree =
  match List.filter is_valid_t_node tree with
  | [ { pstr_desc = Pstr_type (_, [{ptype_kind = Ptype_record label_decls; _}]);
        _ } ] ->
      label_decls
  | [] -> failwith "No `type t = {}` declaration found."
  | _ ->
      failwith
        "Multiple `type t = {}` declarations found, or declaration(s) had \
         invalid structure."

type resource_attribute =
  {name: string; type_name: string; sql_name: string; sql_type_name: string}
(** Specifies how a resource attribute is represented in OCaml source code and SQL. *)

(* TODO - work out which types should be generated *)
(* TODO - generate types without NOT NULL for options *)
let ocaml_type_name_to_sql name type_name =
  let base_sql_type =
    match name with
    | "id" -> (
      match type_name with
      | "int" -> "SERIAL PRIMARY KEY"
      (* TODO - handle int option? *)
      | _ -> failwith "SQL generation for non-int id not supported" )
    | _ -> (
      match type_name with
      | "int" -> "INT"
      | "bool" -> "BOOLEAN"
      | "string" -> "VARCHAR"
      | _ -> failwith ("SQL generation not implemented for type " ^ type_name)
      )
  in
  base_sql_type ^ " NOT NULL"

(* TODO - handle forbidden SQL column names *)
let make_resource_attribute (name, type_name) =
  { name;
    type_name;
    sql_name = name;
    sql_type_name = ocaml_type_name_to_sql name type_name }

(** Given a list of resource attributes, return a string "column_name1, column_name2, ..."
 * (note the lack of parentheses). *)
let column_tuple_string resource_attributes =
  let joined_names =
    String.concat ", " (List.map (fun a -> a.sql_name) resource_attributes)
  in
  joined_names

(** Given a list of resource attibutes, return a string "record_name1, record_name2, ..."
   * or "record_name1; record_name2; ...". *)
let record_names_string resource_attributes sep =
  String.concat sep (List.map (fun a -> a.name) resource_attributes)

(** Given a list of resource attributes, return a string "(tup[n] type1 type2 ...)". *)
let caqti_tuple_type_string resource_attributes =
  let joined_types =
    String.concat " " (List.map (fun a -> a.type_name) resource_attributes)
  in
  let length = List.length resource_attributes in
  if length <= 4 then Printf.sprintf "(tup%d %s)" length joined_types
  else
    (* TODO - generate "tup[n]" for n > 4 *)
    failwith
      "SQL generation not supported for objects with more than 4 attributes..."

(** Given a list of resource attibutes, return a string "~record_name1 ~record_name2 ...". *)
let parameters_string resource_attributes =
  String.concat " " (List.map (fun a -> "~" ^ a.name) resource_attributes)

(** Produce a resource_attribute from a relevant bit of AST. *)
let process_label_decl ({pld_name; pld_type; _} : label_declaration) =
  let type_string =
    match pld_type with
    | {ptyp_desc = Ptyp_constr (ident, _); _} -> (
      match ident.txt with
      | Longident.Lident s -> s
      | _ -> failwith "Unexpected complex long identifiers in record" )
    | _ -> failwith "SQL generation only possible for basic types"
  in
  make_resource_attribute (pld_name.txt, type_string)

(** Extract resource_attributes from label declarations AST. *)
let get_resource_attributes (label_decls : label_declaration list) =
  List.map process_label_decl label_decls

(** Filter the resource_attribute representing ID from a list. *)
let without_id resource_attributes =
  List.filter (fun a -> a.name <> "id") resource_attributes

(** Get the resource_attribute respresenting ID from a list. *)
let get_id_attribute resource_attributes =
  List.find (fun a -> a.name = "id") resource_attributes

(** Generate the code to create the table for a resource. *)
let generate_create_table_sql table_name resource_attributes =
  let column_definitions =
    List.map (fun a -> a.sql_name ^ " " ^ a.sql_type_name) resource_attributes
  in
  let body = String.concat ",\n" column_definitions in
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
    {ocaml|Caqti_request.collect Caqti_type.unit
    Caqti_type.%s
    {sql| SELECT %s FROM %s |sql}

let all (module Db : Caqti_lwt.CONNECTION) =
  Db.fold all_query
    (fun (%s) acc ->
      {%s} :: acc)
    () []|ocaml}
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
  match%%lwt result with
  | Ok data ->
      let record =
        match data with
        | Some (%s) -> Some {%s}
        | None -> None
      in
      Lwt.return record
  | Error _ -> failwith "Error in show query"|ocaml}
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
    Db.find create_query (%s)|ocaml}
    (caqti_tuple_type_string (without_id resource_attributes))
    table_name
    (column_tuple_string (without_id resource_attributes))
    (String.concat ", "
       (List.map (fun _ -> "?") (without_id resource_attributes)))
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

let update (module Db : Caqti_lwt.CONNECTION) id %s =
    Db.exec update_query (%s, id)|ocaml}
    (caqti_tuple_type_string
       (without_id resource_attributes @ [get_id_attribute resource_attributes]))
    table_name
    (column_tuple_string (without_id resource_attributes))
    (String.concat ", "
       (List.map (fun _ -> "?") (without_id resource_attributes)))
    (parameters_string (without_id resource_attributes))
    (record_names_string resource_attributes ", ")

(** Generate model code for destroying a resource instance. *)
let make_destroy_code table_name =
  Printf.sprintf
    {ocaml|let destroy_query =
  Caqti_request.exec Caqti_type.int
    {sql| DELETE FROM %s WHERE id = (?) |sql}

let destroy (module Db : Caqti_lwt.CONNECTION) id = Db.exec destroy_query id|ocaml}
    table_name

let () =
  let oc = open_out "migration_queries.ml" in
  let resource_attributes =
    tree |> get_t_node_labels_ast |> get_resource_attributes
  in
  Printf.fprintf oc "%s\n" (make_migration_code name resource_attributes) ;
  close_out oc

let () =
  let oc = open_out "queries.ml" in
  let resource_attributes =
    tree |> get_t_node_labels_ast |> get_resource_attributes
  in
  let queries =
    [ make_all_code name resource_attributes;
      make_show_code name resource_attributes;
      make_create_code name resource_attributes;
      make_update_code name resource_attributes;
      make_destroy_code name ]
  in
  let queries_string = String.concat "\n\n" queries in
  Printf.fprintf oc "%s\n" queries_string ;
  close_out oc
