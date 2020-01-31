include Specification
module Parameters = Endpoint_parameters.Parameters
module Responses = Endpoint_responses.Responses

module Make = struct
  module Parameters = Endpoint_parameters.Make
  module Responses = Endpoint_responses.Make
end

let handler (module S : Specification.S) input_f impl_f output_f =
  let route = verb_to_route S.verb in
  let handler req =
    let%lwt impl_input = req |> input_f in
    impl_input |> impl_f |> output_f
  in
  route S.path handler
