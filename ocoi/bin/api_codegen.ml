open Core
open Codegen

let make_api_code module_name =
  Printf.sprintf
    {ocaml|open Ocoi.Api

let base_path = "/%s"

module Create = struct
  let verb = Post

  let path = base_path

  module Parameters = struct
    type t = Models.%s.t_no_id

    let t_of_yojson' = Models.%s.t_no_id_of_yojson'
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

  module Parameters = Parameters.Path.One.Int
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

  module Parameters = Parameters.Path.One.Int
  module Responses = Responses.No_content
end|ocaml}
    (Utils.pluralize module_name)
    (String.capitalize module_name)
    (String.capitalize module_name)
    (String.capitalize module_name)
    (String.capitalize module_name)
    (String.capitalize module_name)

let write_api_code ~model_path ~reason =
  let module_name, dir = module_name_and_dir ~model_path in
  let api_name =
    let ( / ) = Filename.concat in
    dir / ".." / "api" / (module_name ^ ".ml")
  in
  let oc = Out_channel.create api_name in
  Printf.fprintf oc "%s\n" (make_api_code module_name);
  Out_channel.close oc;
  Utils.reformat ~reason api_name
