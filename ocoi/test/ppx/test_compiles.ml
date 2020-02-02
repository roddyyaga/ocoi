module M = struct
  type t = { id: int; name: string; cool: bool; another_id: int }
  [@@deriving yojson, ocoi]
end

let f = M.t_no_id_of_yojson'

let g = M.yojson_of_t_no_id
