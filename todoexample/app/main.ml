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

let index_todo =
  get "/todos" (fun _ ->
      let%lwt todo = Todo.index () in
      `Json (todo |> Models.Todo.to_yojson) |> respond')

let _ =
  App.empty |> do_todo_migration |> show_example_todo |> create_example_todo
  |> index_todo |> App.run_command
