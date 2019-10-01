open Core
open Opium.Std

let hello_world =
  get "/" (fun _ ->
      `String "Hello world!\n\nfrom OCaml\n     Ice" |> respond')

let _ =
  let app = App.empty in
  app |> hello_world |> App.run_command
