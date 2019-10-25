open Core
open Codegen

let make_field_get_line resource_attribute =
  let name = resource_attribute.name in
  let type_name = resource_attribute.type_name in
  let json_function =
    match type_name with
    | "int" | "bool" | "string" -> "to_" ^ type_name
    | _ ->
        failwith
          ("CRUD controller generation not implemented for type " ^ type_name)
  in
  let unaligned =
    Printf.sprintf "let %s = json |> member \"%s\" |> %s in" name name
      json_function
  in
  Utils.indent unaligned ~filler:' ' ~amount:4

let make_create resource_attributes =
  String.concat ~sep:"\n" (List.map resource_attributes ~f:make_field_get_line)

let make_controller_code module_name resource_attributes =
  let queries_module = "Queries." ^ String.capitalize module_name in
  let create_parameters = parameters_string (without_id resource_attributes) in
  let record_literal = record_names_string resource_attributes "; " in
  Printf.sprintf
    {ocaml|conn = Db.connection

module Crud : Ocoi.Controllers.Crud = struct
  include Models.%s

  let create json =
    let open Yojson.Safe.Util in
%s
    %s.create conn %s

  let index () = %s.all conn

  let show id = %s.show conn id

  let update {%s} =
    %s.update conn {%s}

  let destroy id = %s.destroy conn id
end|ocaml}
    (String.capitalize module_name)
    (make_create (without_id resource_attributes))
    queries_module create_parameters queries_module queries_module
    record_literal queries_module record_literal queries_module

let write_controller ~model_path ~tree =
  let module_name, dir = module_name_and_dir ~model_path in
  let controller_name =
    let ( / ) = Filename.concat in
    dir / ".." / "controllers" / (module_name ^ ".ml")
  in
  let resource_attributes =
    tree |> get_t_node_labels_ast |> get_resource_attributes
  in
  let oc = Out_channel.create controller_name in
  Printf.fprintf oc "%s\n"
    (make_controller_code module_name resource_attributes) ;
  Out_channel.close oc
