open Core

let ( / ) = Filename.concat

let base_dir = Filename.current_dir_name / "app" / "db" / "migrate"

let up_dir = base_dir / "up"

let down_dir = base_dir / "down"

let get_migrations () =
  let up = Sys.ls_dir up_dir in
  let down = Sys.ls_dir down_dir in
  (up, down)

let check (up, down) =
  let up, down =
    let sort = List.sort ~compare:String.compare in
    (sort up, sort down)
  in
  let paired = List.zip_exn up down in
  List.iter paired ~f:(fun (up, down) -> assert (String.(up = down)));
  up

let make_pool app_name =
  let uri =
    Printf.sprintf "postgresql://%s@%s:5432/%s" app_name "localhost" app_name
  in
  uri |> Uri.of_string |> Caqti_lwt.connect_pool |> function
  | Ok pool -> pool
  | Error _ -> Printf.failwithf "Error connecting to DB with URI %s" uri ()

let get_last_migration =
  [%rapper
    get_opt
      {sql|
      SELECT @string{migration}, @bool{up}, @ptime{applied}
      FROM schema_migrations
      ORDER BY id DESC
      LIMIT 1
      |sql}]

let get_history n dbh =
  let open Lwt_result in
  [%rapper
    get_many
      {sql|
      SELECT @string{migration}, @bool{up}, @ptime{applied}
      FROM schema_migrations
      ORDER BY id DESC
      LIMIT %int{n}
      |sql}]
    ~n dbh
  >|= List.rev

let log_migration ~filename ~up ~applied =
  [%rapper
    execute
      {sql|
      INSERT INTO schema_migrations (migration, up, applied)
      VALUES (%string{migration}, %bool{up}, %ptime{applied})
      |sql}]
    ~migration:filename ~up ~applied

let get_current_index ~app_name migrations =
  let pool = make_pool app_name in
  let execute query = Caqti_lwt.Pool.use query pool in
  let open Lwt_result in
  execute @@ get_last_migration () >|= fun current_opt ->
  match current_opt with
  | Some (filename, is_up, _applied) ->
      let index =
        fst
          (Option.value_exn
             (List.findi migrations ~f:(fun _i name -> String.(name = filename))))
      in
      if is_up then index + 1 else index
  | None -> 0

let run ~app_name execute start migrations target =
  let move, dir, going_up =
    if start < target then ((fun x -> x + 1), up_dir, true)
    else ((fun x -> x - 1), down_dir, false)
  in
  let rec iter current =
    if current = target then Lwt.return_unit
    else
      let filename =
        if going_up then List.nth_exn migrations current
        else List.nth_exn migrations (current - 1)
      in
      let migration = dir / filename in
      Stdio.print_endline migration;
      match
        Unix.system (Printf.sprintf {|psql -U %s -f %s|} app_name migration)
      with
      | Ok () -> (
          let%lwt log_result =
            let applied = Ptime_clock.now () in
            if going_up then
              execute @@ log_migration ~filename ~up:true ~applied
            else execute @@ log_migration ~filename ~up:false ~applied
          in
          match log_result with
          | Ok () -> iter (move current)
          | Error _ -> failwith "Error logging migration to DB" )
      | Error _ -> Stdio.prerr_endline "Error running migration" |> Lwt.return
  in
  let%lwt () = iter start in
  Ok () |> Lwt.return

let wrap_lwt_result result_lwt error_message =
  let%lwt result = result_lwt in
  match result with
  | Ok () -> () |> Lwt.return
  | Error _ -> failwith error_message

let do_migration app_name migrations target =
  let pool = make_pool app_name in
  let execute query = Caqti_lwt.Pool.use query pool in
  let main () =
    let run_result =
      let open Lwt_result in
      get_current_index ~app_name migrations >>= fun start ->
      run ~app_name execute start migrations target
    in
    wrap_lwt_result run_result "Error getting migration history from DB"
  in
  Lwt_main.run (main ())

let do_rollback app_name migrations steps =
  let pool = make_pool app_name in
  let execute query = Caqti_lwt.Pool.use query pool in
  let main () =
    let run_result =
      let open Lwt_result in
      get_current_index ~app_name migrations >>= fun start ->
      let target = start - steps in
      let target = Int.clamp_exn ~min:0 ~max:(List.length migrations) target in
      run ~app_name execute start migrations target
    in
    wrap_lwt_result run_result "Error getting migration history from DB"
  in
  Lwt_main.run (main ())

let status ~app_name () =
  let pool = make_pool app_name in
  let execute query = Caqti_lwt.Pool.use query pool in
  let main () =
    let result =
      let open Lwt_result in
      execute @@ get_last_migration () >|= fun start_opt ->
      match start_opt with
      | None -> Stdio.print_endline "No migrations have been run"
      | Some (migration, was_up, applied) ->
          let direction = if was_up then "up" else "down" in
          let timestamp = Format.asprintf "%a" (Ptime.pp_human ()) applied in
          Stdio.printf "Last migration was %s %s at %s\n" migration direction
            timestamp
    in
    wrap_lwt_result result "Error getting migration history from DB"
  in
  Lwt_main.run (main ())

let history ~app_name n =
  let pool = make_pool app_name in
  let execute query = Caqti_lwt.Pool.use query pool in
  let main () =
    let result =
      let open Lwt_result in
      execute @@ get_history n >|= fun logs ->
      List.iter logs ~f:(fun (migration, was_up, applied) ->
          let direction = if was_up then "up" else "down" in
          let timestamp = Format.asprintf "%a" (Ptime.pp_human ()) applied in
          Stdio.printf "%s %s %s\n" timestamp migration direction)
    in
    wrap_lwt_result result "Error getting migration history from DB"
  in
  Lwt_main.run (main ())
