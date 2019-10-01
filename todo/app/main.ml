open Core
open Opium.Std
open Controllers

let hello_world =
  get "/" (fun _ ->
      `String "Hello world!\n\nfrom OCaml\n     Ice" |> respond')

let _ =
  let app = App.empty in
  let app = Ocoi.Controllers.register_rud "/todos" (module Todo.Rud) app in
  app |> hello_world |> App.run_command
