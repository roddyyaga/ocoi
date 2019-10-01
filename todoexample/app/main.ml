open Core
open Opium.Std
open Controllers

let do_todo_migration =
  get "/todos/migrate" (fun _ ->
      let _ = Todo.do_migration () in
      `String "Migration done!" |> respond')

let show_example_todo =
  get "/todos/example" (fun _ ->
      let todo = Todo.example_todo in
      `Json (todo |> Models.Todo.to_yojson) |> respond')

let create_example_todo =
  get "/todos/example/create" (fun _ ->
      let _ = Todo.create_example () in
      `String "Example created!" |> respond')

let create_todo =
  post "/todos" (fun req ->
      let%lwt json = App.json_of_body_exn req in
      let open Yojson.Safe.Util in
      let title = json |> member "title" |> to_string in
      let completed = json |> member "completed" |> to_bool in
      let%lwt id = Todo.create ~title ~completed in
      let open Ocoi.Handler_utils in
      empty_created_response (Printf.sprintf "/todos/%d" id))

let _ =
  let app = App.empty in
  let app = Ocoi.Controllers.register_rud "/todos" (module Todo.Rud) app in
  app |> do_todo_migration |> show_example_todo |> create_example_todo
  |> App.run_command
