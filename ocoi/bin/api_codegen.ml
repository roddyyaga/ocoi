open Core
open Codegen

let make_api_code module_name resource_attributes =
  let create_parameters =
    record_names_string (without_id resource_attributes) ";"
  in
  Printf.sprintf
    {ocaml|open Ocoi.Endpoints

let base_path = "/%s"

module Create = struct
  let verb = Post

  let path = base_path

  module Parameters = struct
    type t = { %s }
    [@@deriving yojson]
  end

  module Responses = Responses.Created.Int
end

module Index = struct
  let verb = Get

  let path = base_path

  module Parameters = Parameters.None
  module Responses = Responses.Json_list (Models.%s)
end

module Show = struct
  let verb = Get

  let path = base_path ^ "/:id"

  module Parameters = Parameters.One_param.Int
  module Responses = Responses.Json_opt (Models.%s)
end

module Update = struct
  let verb = Put

  let path = base_path

  module Parameters = Models.%s
  module Responses = Responses.No_content
end

module Destroy = struct
  let verb = Delete

  let path = base_path ^ "/:id"

  module Parameters = Parameters.One_param.Int
  module Responses = Responses.No_content
end
    |ocaml}
    (Utils.pluralize module_name)
    create_parameters
    (String.capitalize module_name)
    (String.capitalize module_name)
    (String.capitalize module_name)

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
  Printf.fprintf oc "%s\n" (make_api_code module_name resource_attributes);
  Out_channel.close oc
