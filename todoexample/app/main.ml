(* TODO - extract response logic into code generation/controller/functor thing *)
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

let index_todo =
  get "/todos" (fun _ ->
      let%lwt todos = Todo.index () in
      let todos_json = List.map todos ~f:Models.Todo.to_yojson in
      `Json (`List todos_json) |> respond')

let empty_response code = `String "" |> respond' ~code

let empty_created_response location =
  `String ""
  |> respond'
       ~headers:(Cohttp.Header.of_list [("Location", location)])
       ~code:`Created

let respond_bad_request_400 err = `String err |> respond' ~code:`Bad_request

let show_todo =
  get "/todos/:id" (fun req ->
      let%lwt todo_opt = Todo.show (int_of_string (param req "id")) in
      match todo_opt with
      | Some todo -> `Json (todo |> Models.Todo.to_yojson) |> respond'
      | None -> empty_response `Not_found)

let create_todo =
  post "/todos" (fun req ->
      let%lwt json = App.json_of_body_exn req in
      let open Yojson.Safe.Util in
      let title = json |> member "title" |> to_string in
      let completed = json |> member "completed" |> to_bool in
      let%lwt id = Todo.create ~title ~completed in
      empty_created_response (Printf.sprintf "/todos/%d" id))

let update_todo =
  put "/todos" (fun req ->
      let%lwt json = App.json_of_body_exn req in
      let todo_err = Models.Todo.of_yojson json in
      match todo_err with
      | Ok todo ->
          let%lwt () = Todo.update todo in
          empty_response `No_content
      (* TODO - make error message nicer *)
      | Error err ->
          respond_bad_request_400 ("(At least one) bad field: " ^ err))

let destroy_todo =
  delete "/todos/:id" (fun req ->
      let%lwt () = Todo.destroy (int_of_string (param req "id")) in
      empty_response `No_content)

let _ =
  App.empty |> show_todo |> create_todo |> do_todo_migration
  |> show_example_todo |> create_example_todo |> update_todo |> index_todo
  |> destroy_todo |> App.run_command
