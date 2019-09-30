open Core

let generate_model =
  Command.basic ~summary:"Generate CRUD DB code for a model"
    Command.Let_syntax.(
      let%map_open name = anon ("name" %: Filename.arg_type) in
      fun () ->
        let tree =
          Pparse.parse_implementation Format.std_formatter ~tool_name:"ocamlc"
            name
        in
        Db_codegen.write_migration_queries name tree ;
        Db_codegen.write_crud_queries name tree)

let generate =
  Command.group ~summary:"Generate various kinds of code"
    [("model", generate_model)]

let new_ =
  Command.basic ~summary:"Create an empty project (not yet implemented)"
    Command.Let_syntax.(
      let%map_open name = anon ("name" %: Filename.arg_type) in
      (* TODO - sanitise name *)
      fun () ->
        let template_directory_name =
          FilePath.concat
            (FilePath.dirname Sys.argv.(0))
            "../share/project_template"
        in
        let () = FileUtil.cp ~recurse:true [template_directory_name] name in
        print_endline template_directory_name)

let command =
  Command.group ~summary:"Run OCOI commands"
    [("generate", generate); ("new", new_)]

let () = Command.run command
