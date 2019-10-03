open Core

(** Read lines indefinitely from an in_channel, displaying `f line` for each
 * and then `channel_finished` if/when the channel is closed. *)
let rec display_lines ic ~f ~channel_finished =
  match%lwt Lwt_io.read_line_opt ic with
  | Some s ->
      let () = print_endline (f s) in
      display_lines ic ~f ~channel_finished
  | None -> print_endline channel_finished |> Lwt.return

let kill process =
  let pid = process.Unix.Process_info.pid in
  (* Redirect stderr to stdout so it is captured rather than printed *)
  let status =
    Printf.sprintf "kill %d 2>&1" (Pid.to_int pid)
    (* TODO - determine if this is the best way of running a process *)
    |> Unix.open_process
    |> Unix.close_process
  in
  (* TODO - log something if run in verbose mode *)
  match status with Ok () -> () | Error _ -> ()

(** Asynchronously wait until a process terminates and then do something based on the result. *)
let watch_for_server_end process ~f =
  let task () =
    let result =
      match%lwt
        Lwt_unix.waitpid [] (Pid.to_int process.Unix.Process_info.pid)
      with
      | 0, _ -> f None
      | i, _ -> f (Some i)
    in
    result
  in
  Lwt.async task

(** Asynchronously call display_lines on a file descriptor, for instance stdout or stderr of a process *)
let watch_file_descr_output descr ~f ~channel_finished =
  let descr = descr |> Lwt_unix.of_unix_file_descr in
  let ic = Lwt_io.(of_fd ~mode:input descr) in
  Lwt.async (fun () -> display_lines ic ~f ~channel_finished |> Lwt.return)

(* TODO - force messages about closing channels/server finishing to be printend
 * before "Server built and started" *)
(* TODO - split into build and run steps *)
(* TODO - pass options to server down to main.exe *)

(** Start a server
 * and asynchronously print its stdout and stderr and watch for its termination status *)
let start_server () =
  let result =
    Unix.create_process ~prog:"dune" ~args:["exec"; "--"; "./main.exe"; "-d"]
  in
  let () = print_endline "Server built and started" in
  let () =
    watch_file_descr_output result.stdout
      ~f:(fun s -> "STDOUT: " ^ s)
      ~channel_finished:"STDOUT closed"
  in
  let () =
    watch_file_descr_output result.stderr
      ~f:(fun s -> "STDERR: " ^ s)
      ~channel_finished:"STDERR closed"
  in
  let () =
    watch_for_server_end result ~f:(fun x ->
        let () =
          match x with
          | None -> print_endline "Previous server finished successfully"
          | Some _ ->
              print_endline "Previous server killed or finished with error"
        in
        Lwt.return ())
  in
  result

(** Kill a server and start a new one *)
let restart_server server =
  let () = kill server in
  let () = print_endline "Server killed" in
  let new_server = start_server () in
  new_server

(** Restart a server every time a line is read from the output of some process.
 * *)
let restart_on_change ~server ~watchtool_output ~freq =
  (* TODO - use version in some situations *)
  let rec restart_on_change_after ~restart_time ~server ~version =
    let ic =
      watchtool_output
      |> Lwt_unix.of_unix_file_descr ~blocking:true
      |> Lwt_io.(of_fd ~mode:input)
    in
    match%lwt Lwt_io.read_line_opt ic with
    | Some _ -> (
        let current_time = Unix.time () in
        match current_time >= restart_time with
        | true ->
            let () =
              print_endline "\nChange detected, rebuilding and restarting"
            in
            let new_server = restart_server server in
            restart_on_change_after ~restart_time:(current_time +. freq)
              ~server:new_server ~version:(version + 1)
        | false -> restart_on_change_after ~restart_time ~server ~version )
    | None -> failwith "Unexpected end of input channel!"
  in
  restart_on_change_after ~restart_time:0.0 ~server ~version:1
