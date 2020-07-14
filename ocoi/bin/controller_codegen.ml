open Core
open Codegen

let make_controller_code module_name resource_attributes =
  Printf.sprintf
    {ocaml|open Models.%s

let create { No_id.%s }=
  Db.execute @@ Queries.%s.create %s

let index () = Db.execute @@ Queries.%s.all ()

let show id = Db.execute @@ Queries.%s.show id

let update { %s }=
  Db.execute @@ Queries.%s.update { %s }

let destroy id = Db.execute @@ Queries.%s.destroy id|ocaml}
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
