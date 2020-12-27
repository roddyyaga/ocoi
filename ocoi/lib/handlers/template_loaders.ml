open Base
open Jingoo

let literal s = Jg_template.Loaded.from_string s

let cache = Hashtbl.create (module String)

let file s =
  Hashtbl.find_or_add cache s ~default:(fun () ->
      Jg_template.Loaded.from_file s)
