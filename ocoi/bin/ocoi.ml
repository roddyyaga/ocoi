open Core

let generate_queries =
  (* TODO - fill out readmes *)
  Command.basic ~summary:"Generate CRUD DB code for a model"
    Command.Let_syntax.(
      let%map_open name = anon ("name" %: Filename.arg_type) in
      fun () ->
        let tree = Codegen.load_tree name in
        Db_codegen.write_migration_queries name tree ;
        Db_codegen.write_crud_queries name tree)

let generate_controller =
  Command.basic ~summary:"Generate CRUD controller code for a model"
    Command.Let_syntax.(
      let%map_open name = anon ("name" %: Filename.arg_type) in
      fun () ->
        let tree = Codegen.load_tree name in
        Controller_codegen.write_controller name tree)

let generate_scaffold =
  Command.basic ~summary:"Generate CRUD controller and DB code for a model"
    ~readme:(fun () ->
      "Currently just does `ocoi generate queries` and `ocoi generate \
       controller`.")
    Command.Let_syntax.(
      let%map_open name = anon ("name" %: Filename.arg_type) in
      fun () ->
        let tree = Codegen.load_tree name in
        Db_codegen.write_migration_queries name tree ;
        Db_codegen.write_crud_queries name tree ;
        Controller_codegen.write_controller name tree)

let generate =
  Command.group ~summary:"Generate various kinds of code"
    [ ("queries", generate_queries);
      ("controller", generate_controller);
      ("scaffold", generate_scaffold) ]

let new_ =
  Command.basic ~summary:"Create an empty project"
    Command.Let_syntax.(
      let%map_open name = anon ("name" %: Filename.arg_type) in
      (* TODO - sanitise name *)
      fun () ->
        let template_directory_name =
          FilePath.concat
            ("ocoi" |> FileUtil.which |> FilePath.dirname)
            "../share/ocoi/project_template"
        in
        FileUtil.cp ~recurse:true [template_directory_name] name)

let server =
  Command.basic ~summary:"Run an OCOI app, rebuilding when files are changed"
    ~readme:(fun () ->
      "This should be called from the app directory. It uses `main.ml` as an \
       entry point. It is implemented by rerunning `dune exec -- ./main.exe` \
       when inotifywait detects changes.")
    (Command.Param.return (fun () ->
         let () = print_endline "Starting server" in
         let server = Server.start_server () in
         (* TODO - optimise inotifywait command (e.g. limit to certain file types) *)
         (* FIXME - sometimes it seem to watch the _build directory even though it should be excluded *)
         let watch_args =
           [ "-mr";
             "-e";
             "modify";
             "-e";
             "attrib";
             "-e";
             "close_write";
             "-e";
             "moved_to";
             "-e";
             "moved_from";
             "-e";
             "create";
             "-e";
             "delete";
             "-e";
             "delete_self";
             "@./_build/";
             "." ]
         in
         (* let fswatch_output = Unix.open_process_in watch_command in *)
         let fswatch_output =
           (Unix.create_process ~prog:"inotifywait" ~args:watch_args).stdout
         in
         (* TODO - ensure spawned processes are nicely cleaned up when killed *)
         Lwt_main.run (Server.restart_on_change server fswatch_output 2.0)))

let command =
  Command.group ~summary:"Run OCOI commands"
    [("generate", generate); ("new", new_); ("server", server)]

let () = Command.run command
