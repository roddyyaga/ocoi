open Core

(** Indent each line in a multiline string by [amount] copies of [filler]

    [filler] is a char, not a string. *)
let indent s ~filler ~amount =
  let lines = String.split_lines s in
  let indented_lines =
    List.map lines ~f:(fun line -> String.make amount filler ^ line)
  in
  String.concat ~sep:"\n" indented_lines

(* TODO - implement more sophisticated pluralisation *)
let pluralize word = word ^ "s"

(** Run ocamlformat on a file in place *)
let ocamlformat path =
  Unix.create_process ~prog:"ocamlformat" ~args:[ "--inplace"; path ]

(** Run refmt on a file in place, changing the suffix *)
let refmt path =
  let new_path = String.chop_suffix_exn ~suffix:"ml" path ^ "re" in
  let command =
    Printf.sprintf "refmt --parse=ml %s > %s && rm %s" path new_path path
  in
  Unix.system command

(** Run either ocamlformat or refmt on a file in place *)
let reformat path ~reason =
  match reason with
  | true ->
      let _ = refmt path in
      ()
  | false ->
      let _ = ocamlformat path in
      ()

(** Check we are in the root project directory *)
let check_in_root () =
  if
    not
      (List.mem ~equal:String.equal
         (Sys.ls_dir Filename.current_dir_name)
         "app")
  then
    failwith
      "This command must be run from the root project directory (the one \
       containing `app`)."

let get_app_name () =
  check_in_root ();
  Unix.getcwd () |> Filename.basename

(** Get the index of the last element in a list satisfying a predicate *)
let index_last xs ~f =
  let reversed_index_opt = List.findi (List.rev xs) ~f:(fun _i x -> f x) in
  match reversed_index_opt with
  | Some reversed_index -> Some (List.length xs - fst reversed_index - 1)
  | None -> None
