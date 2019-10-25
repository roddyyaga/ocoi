open Core
open Asttypes
open Parsetree

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
  match List.filter tree ~f:is_valid_t_node with
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

(* TODO - update generated code to match changes to example project code *)
(* TODO - work out which postgres types would be best to generate *)
(* TODO - generate types without NOT NULL for options *)
(* TODO - generate types for enums *)
(* TODO - generate types for foreign keys *)
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

(** Produce a resource_attribute from a relevant bit of AST. *)
let make_resource_attribute (name, type_name) =
  { name;
    type_name;
    sql_name = name;
    sql_type_name = ocaml_type_name_to_sql name type_name }

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
  List.map label_decls ~f:process_label_decl

(** Given a list of resource attibutes, return a string "~record_name1 ~record_name2 ...". *)
let parameters_string resource_attributes =
  String.concat ~sep:" "
    (List.map resource_attributes ~f:(fun a -> "~" ^ a.name))

(** Filter the resource_attribute representing ID from a list. *)
let without_id resource_attributes =
  List.filter resource_attributes ~f:(fun a -> a.name <> "id")

(** Get the resource_attribute representing ID from a list. *)
let get_id_attribute resource_attributes =
  List.find_exn resource_attributes ~f:(fun a -> a.name = "id")

(** Given a list of resource attibutes, return a string "record_name1, record_name2, ..."
   * or "record_name1; record_name2; ...". *)
let record_names_string resource_attributes sep =
  String.concat ~sep (List.map resource_attributes ~f:(fun a -> a.name))

(** Load an AST tree from a filename. *)
let load_tree ~model_path =
  Pparse.parse_implementation Format.std_formatter ~tool_name:"ocamlc"
    model_path

(** [module_name_and dir "path/to/model.ml"] returns [("model", "path/to")] *)
let module_name_and_dir ~model_path =
  let module_name = Filename.(model_path |> chop_extension |> basename) in
  let dir = Filename.(dirname model_path) in
  (module_name, dir)
