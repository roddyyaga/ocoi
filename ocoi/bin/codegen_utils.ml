open Asttypes
open Parsetree
open Core

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
