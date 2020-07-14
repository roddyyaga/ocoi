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
  Printf.sprintf "postgresql://%s@%s:5432/%s" app_name "localhost" app_name
  |> Uri.of_string |> Caqti_lwt.connect_pool
  |> function
  | Ok pool -> pool
  | Error _ -> failwith "Error connecting to DB"

let get_last_migration =
  [%rapper
    get_opt
      {sql|
      SELECT @string{migration}, @bool{up}
      FROM schema_migrations
      ORDER BY id DESC
      LIMIT 1
      |sql}]

let log_migration ~filename ~up =
  [%rapper
    execute
      {sql|
      INSERT INTO schema_migrations (migration, up)
      VALUES (%string{migration}, %bool{up})
      |sql}]
    ~migration:filename ~up

let get_current_index ~app_name migrations =
  let pool = make_pool app_name in
  let execute query = Caqti_lwt.Pool.use query pool in
  let open Lwt_result in
  execute @@ get_last_migration () >|= fun current_opt ->
  match current_opt with
  | Some (filename, is_up) ->
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
      let filename = List.nth_exn migrations current in
      let migration = dir / filename in
      Stdio.print_endline migration;
      match
        Unix.system (Printf.sprintf {|psql -U %s -f %s|} app_name migration)
      with
      | Ok () -> (
          let%lwt log_result =
            if going_up then execute @@ log_migration ~filename ~up:true
            else execute @@ log_migration ~filename ~up:false
          in
          match log_result with
          | Ok () -> iter (move current)
          | Error _ -> failwith "Error logging migration to DB" )
      | Error _ -> Stdio.prerr_endline "Error running migration" |> Lwt.return
  in
  let%lwt () = iter start in
  Ok () |> Lwt.return

let do_migration app_name migrations target =
  let pool = make_pool app_name in
  let execute query = Caqti_lwt.Pool.use query pool in
  let main () =
    let%lwt run_result =
      let open Lwt_result in
      get_current_index ~app_name migrations >>= fun start ->
      run ~app_name execute start migrations target
    in
    match run_result with
    | Ok () -> () |> Lwt.return
    | Error _ -> failwith "Error getting migration history from DB"
  in
  Lwt_main.run (main ())

let do_rollback app_name migrations steps =
  let pool = make_pool app_name in
  let execute query = Caqti_lwt.Pool.use query pool in
  let main () =
    let%lwt run_result =
      let open Lwt_result in
      get_current_index ~app_name migrations >>= fun start ->
      let target = start - steps in
      let target =
        Int.clamp_exn ~min:0 ~max:(1 + List.length migrations) target
      in
      run ~app_name execute start migrations target
    in
    match run_result with
    | Ok () -> () |> Lwt.return
    | Error _ -> failwith "Error getting migration history from DB"
  in
  Lwt_main.run (main ())
