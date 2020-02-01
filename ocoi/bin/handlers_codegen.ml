open Core
open Codegen

let make_crud_code module_name =
  Printf.sprintf
    (* Add newlines at start and end for safety *)
    {ocaml|
let %s =
  Ocoi.Handlers.crud
    ( module struct
      module Api = Api.%s
      module Controller = Controllers.%s
   end )
|ocaml}
    module_name
    (String.capitalize module_name)
    (String.capitalize module_name)

(* :-( *)
let handlers_pattern =
  Str.regexp
    "\\(let[ \t\n\
     ]+handlers[ \t\n\
     ]+=[ \t\n\
     ]+List.flatten[ \t\n\
     ]+\\[\\)\\(.*\\)\\(\\]$\\)"

let add_crud ~model_path =
  let module_name, dir = module_name_and_dir ~model_path in
  let handlers_filename =
    let ( / ) = Filename.concat in
    dir / ".." / "handlers.ml"
  in
  let current_handlers_content = In_channel.read_all handlers_filename in
  let match_pos =
    Str.search_forward handlers_pattern current_handlers_content 0
  in
  let before_match = String.prefix current_handlers_content match_pos in
  let new_crud = make_crud_code module_name in
  let before_list = Str.matched_group 1 current_handlers_content in
  let current_handlers_list_contents =
    Str.matched_group 2 current_handlers_content
  in
  let after_list = Str.matched_group 3 current_handlers_content in
  let new_list_contents =
    Printf.sprintf "%s; %s" current_handlers_list_contents module_name
  in
  let new_handlers_contents =
    String.concat
      [ before_match; new_crud; before_list; new_list_contents; after_list ]
  in
  Out_channel.write_all handlers_filename ~data:new_handlers_contents;
  let _ = Utils.ocamlformat handlers_filename in
  ()
