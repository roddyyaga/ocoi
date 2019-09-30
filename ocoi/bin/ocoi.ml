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

let start_server () =
  Unix.create_process ~prog:"dune" ~args:["exec"; "--"; "./main.exe"]

let kill pid =
  let status = Sys.command (Printf.sprintf "kill %d" pid) in
  match status with
  | 0 -> ()
  | _ -> failwith (Printf.sprintf "Could not kill process with pid %d" pid)

let restart_server server =
  let () = kill (Pid.to_int server.Unix.Process_info.pid) in
  print_endline "Server recompiled and restarted!" ;
  start_server ()

let rec restart_on_change server fswatch_output =
  match In_channel.input_line fswatch_output with
  | Some s ->
      let () = print_endline s in
      let new_server = restart_server server in
      restart_on_change new_server fswatch_output
  | None -> failwith "Unexpected end of input channel!"

let server =
  Command.basic ~summary:"Run an OCOI app, rebuilding when files are changed"
    ~readme:(fun () ->
      "This should be called from the app directory. It uses `main.ml` as an \
       entry point. It is implemented by rerunning `dune exec -- ./main.exe` \
       when fswatch detects changes.")
    (Command.Param.return (fun () ->
         let server = start_server () in
         let watch_command =
           {|fswatch -xr --event Created --event Updated --event Removed \
            --event Renamed --event OwnerModified --event AttributeModified \
            --event MovedFrom --event MovedTo -e ".*_build/.*" .|}
         in
         let fswatch_output = Unix.open_process_in watch_command in
         restart_on_change server fswatch_output))

let command =
  Command.group ~summary:"Run OCOI commands"
    [("generate", generate); ("new", new_); ("server", server)]

let () = Command.run command
