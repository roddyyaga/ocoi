module M = struct
  type t = { id: int; name: string; cool: bool; another_id: int }
  [@@deriving yojson, ocoi]
end

let f = M.No_id.t_of_yojson

let g = M.No_id.yojson_of_t
