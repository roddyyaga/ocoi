type t = { id: int; name: string; cool: bool; another_id: int }
[@@deriving yojson, ocoi]
