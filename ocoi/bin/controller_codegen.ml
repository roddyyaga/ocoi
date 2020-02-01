open Core
open Codegen

let make_controller_code module_name resource_attributes =
  Printf.sprintf
    {ocaml|open Api.%s
open Models.%s

let create Create.Parameters.{ %s }=
  Queries.%s.create Db.connection %s

let index () = Queries.%s.all Db.connection ()

let show id = Queries.%s.show Db.connection id

let update { %s }=
  Queries.%s.update Db.connection { %s }

let destroy id = Queries.%s.destroy Db.connection id|ocaml}
    (String.capitalize module_name)
    (String.capitalize module_name)
    (record_names_string (without_id resource_attributes) "; ")
    (String.capitalize module_name)
    (ocaml_parameters_string (without_id resource_attributes))
    (String.capitalize module_name)
    (String.capitalize module_name)
    (record_names_string resource_attributes "; ")
    (String.capitalize module_name)
    (record_names_string resource_attributes "; ")
    (String.capitalize module_name)

let write_controller ~model_path ~tree ~reason =
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
    (make_controller_code module_name resource_attributes);
  Out_channel.close oc;
  Utils.reformat ~reason controller_name
