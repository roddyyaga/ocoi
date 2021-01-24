open Ocoi.Handlers

let hello_world =
  let hello =
    let module P = Make.Parameters.None (Api.Hello.Parameters) in
    let module R = Make.Responses.String (Api.Hello.Responses) in
    handler (module Api.Hello) P.f Controllers.Hello.hello R.f
  in
  [ hello ]

let handlers = List.flatten [ hello_world ]
