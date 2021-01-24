open Core

let generate_queries =
  (* TODO - fill out readmes *)
  Command.basic ~summary:"Generate CRUD DB code for a model"
    Command.Let_syntax.(
      let%map_open model_path = anon ("model_path" %: Filename.arg_type)
      and reason =
        flag "-reason" no_arg ~doc:" use Reason syntax rather than OCaml"
      in
      fun () ->
        let tree = Codegen.load_tree ~model_path in
        Db_codegen_rapper.write_queries ~model_path ~tree ~reason)

let generate_controller =
  Command.basic ~summary:"Generate CRUD controller code for a model"
    Command.Let_syntax.(
      let%map_open model_path = anon ("model_path" %: Filename.arg_type)
      and reason =
        flag "-reason" no_arg ~doc:" use Reason syntax rather than OCaml"
      in
      fun () ->
        let tree = Codegen.load_tree ~model_path in
        Controller_codegen.write_controller ~model_path ~tree ~reason)

let generate_api =
  Command.basic ~summary:"Generate CRUD API code for a model"
    Command.Let_syntax.(
      let%map_open model_path = anon ("model_path" %: Filename.arg_type)
      and reason =
        flag "-reason" no_arg ~doc:" use Reason syntax rather than OCaml"
      in
      fun () -> Api_codegen.write_api_code ~model_path ~reason)

let generate_handlers =
  Command.basic ~summary:"Generate handlers for CRUD endpoints for a model"
    Command.Let_syntax.(
      let%map_open model_path = anon ("model_path" %: Filename.arg_type) in
      fun () -> Handlers_codegen.add_crud ~model_path)

let generate_scaffold =
  (* TODO - pluralise name *)
  Command.basic ~summary:"Generate CRUD controller and DB code for a model"
    ~readme:(fun () ->
      "Equivalent to `ocoi generate queries && ocoi generate controller && \
       ocoi generate handlers`.")
    Command.Let_syntax.(
      let%map_open model_path = anon ("model_path" %: Filename.arg_type)
      and reason =
        flag "-reason" no_arg ~doc:" use Reason syntax rather than OCaml"
      in

      fun () ->
        let tree = Codegen.load_tree ~model_path in
        Db_codegen_rapper.write_queries ~model_path ~tree ~reason;
        Controller_codegen.write_controller ~model_path ~tree ~reason;
        Api_codegen.write_api_code ~model_path ~reason;
        Handlers_codegen.add_crud ~model_path)

let generate =
  Command.group ~summary:"Generate various kinds of code"
    [
      ("queries", generate_queries);
      ("controller", generate_controller);
      ("handlers", generate_handlers);
      ("scaffold", generate_scaffold);
    ]

let new_ =
  Command.basic ~summary:"Create an empty project"
    Command.Let_syntax.(
      let%map_open name = anon ("name" %: Filename.arg_type)
      and reason =
        flag "-reason" no_arg ~doc:" use Reason syntax rather than OCaml"
      in
      (* TODO - sanitise name *)
      fun () ->
        let template_directory_name =
          Filename.concat
            ("ocoi" |> FileUtil.which |> Filename.dirname)
            "../share/ocoi/project_template"
        in
        FileUtil.cp ~recurse:true [ template_directory_name ] name;
        let ( / ) = Filename.concat in
        Unix.mkdir_p (name / "db" / "migrate" / "up");
        Unix.mkdir_p (name / "db" / "migrate" / "down");

        let db_code =
          Printf.sprintf
            {ocaml|open Core

let hostname =
  match Sys.getenv "POSTGRES_HOSTNAME" with Some s -> s | None -> "localhost"

let pool =
  Ocoi.Db.make_pool
    (Printf.sprintf "postgresql://%s@%%s:5432/%s" hostname)

        let execute query = Caqti_lwt.Pool.use query pool|ocaml}
            name name
        in
        let db_path = name / "db" / "db.ml" in
        Out_channel.write_all db_path ~data:db_code;

        let main_path = name / "main.ml" in
        let hello_api = name / "api" / "hello.ml" in
        let hello_controller = name / "controllers" / "hello.ml" in
        (* Do not reformat handlers.ml:
         * that can't use Reason syntax with the current hacky way of updating it *)
        List.iter ~f:(Utils.reformat ~reason)
          [ main_path; db_path; hello_api; hello_controller ];
        Stdio.print_endline "Creating project database and user";
        Db.setup_database name)

let db_setup =
  Command.basic ~summary:"Setup database for project"
    ~readme:(fun () ->
      "This should be called from the root project directory. The database is \
       setup automatically when you run `ocoi new` - this command is for \
       situations such as after checking out a project from version control.")
    (Command.Param.return (fun () ->
         let name = Utils.get_app_name () in
         Db.setup_database name))

let migrate =
  Command.basic ~summary:"Run DB migrations"
    ~readme:(fun () ->
      {|This should be called from the root project directory.

With no timestamp, will execute all migrations that haven't been run.
With a timestamp (in the same %Y%m%dT%H%M%SZ format as migration filenames), will make or rollback migrations until the database is in the state just after running all migrations with that timestamp.
      |})
    Command.Let_syntax.(
      let%map_open target_version =
        flag "-version" (optional string)
          ~doc:
            {|target version to migrate to (default most recent). Should be a timestamp of the same form as the migration files.|}
      in
      fun () ->
        let app_name = Utils.get_app_name () in
        let migrations = Migrations.(get_migrations () |> check) in
        let target =
          match target_version with
          | Some version -> (
              match
                Utils.index_last migrations
                  ~f:(String.is_prefix ~prefix:version)
              with
              | Some i -> i + 1
              | None ->
                  Printf.failwithf "No migration has timestamp '%s'" version ()
              )
          | None -> List.length migrations
        in
        Migrations.do_migration app_name migrations target)

let rollback =
  Command.basic ~summary:"Undo some migrations"
    ~readme:(fun () -> "Rollback some number of migrations (default 1).")
    Command.Let_syntax.(
      let%map_open steps = anon (maybe ("steps" %: int)) in
      fun () ->
        let app_name = Utils.get_app_name () in
        let migrations = Migrations.(get_migrations () |> check) in
        let steps = Option.value steps ~default:1 in
        Migrations.do_rollback app_name migrations steps)

let rollforward =
  Command.basic ~summary:"Apply a number of migrations"
    ~readme:(fun () -> "Apply some number of migrations (default 1).")
    Command.Let_syntax.(
      let%map_open steps = anon (maybe ("steps" %: int)) in
      fun () ->
        let app_name = Utils.get_app_name () in
        let migrations = Migrations.(get_migrations () |> check) in
        let steps = Option.value steps ~default:1 in
        Migrations.do_rollback app_name migrations (-steps))

let db_status =
  Command.basic ~summary:"View the last migration applied to the database"
    (Command.Param.return (fun () ->
         let app_name = Utils.get_app_name () in
         Migrations.status ~app_name ()))

let db_history =
  Command.basic ~summary:"View a history of migrations that have been applied"
    Command.Let_syntax.(
      let%map_open length = anon (maybe ("length" %: int)) in
      fun () ->
        let length = Option.value length ~default:1 in
        let app_name = Utils.get_app_name () in
        Migrations.history ~app_name length)

let db =
  Command.group
    ~summary:"Set up the database, run migrations, view applied migrations."
    [
      ("setup", db_setup);
      ("migrate", migrate);
      ("rollback", rollback);
      ("rollforward", rollforward);
      ("status", db_status);
      ("history", db_history);
    ]

let server =
  Command.basic ~summary:"Run an ocoi app, rebuilding when files are changed"
    ~readme:(fun () ->
      "This should be called from the root project directory. It uses \
       `main.ml` as an entry point. It is implemented by rerunning `dune exec \
       -- ./bin/main.exe` when inotifywait detects changes.")
    (Command.Param.return (fun () ->
         let () = print_endline "Starting server" in
         let server = Server.start_server () in
         (* TODO - optimise inotifywait command (e.g. limit to certain file types) *)
         (* FIXME - sometimes it seem to watch the _build directory even though it should be excluded *)
         let watch_args =
           [
             "-mr";
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
             "--exclude";
             "(.*_build.*)|(.*node_modules/\\.lsp/.*)|(.*\\.merlin.*)";
             ".";
           ]
         in
         let watchtool_output =
           (Unix.create_process ~prog:"inotifywait" ~args:watch_args).stdout
         in
         (* TODO - ensure spawned processes are nicely cleaned up when killed *)
         Lwt_main.run
           (* TODO - make 2 second maximum restart frequency configurable *)
           (Server.restart_on_change ~server ~watchtool_output ~freq:2.0)))

let command =
  Command.group ~summary:"Run ocoi commands"
    [ ("generate", generate); ("new", new_); ("server", server); ("db", db) ]

let () = Command.run command
