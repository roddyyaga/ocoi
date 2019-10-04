open Core

(** Indent each line in a multiline string by [amount] copies of [filler]

    [filler] is a char, not a string. *)
let indent s ~filler ~amount =
  let lines = String.split_lines s in
  let indented_lines =
    List.map lines ~f:(fun line -> String.make amount filler ^ line)
  in
  String.concat ~sep:"\n" indented_lines
