let explode_string s = List.init (String.length s) (String.get s)
let list_count f xs = List.length (List.filter f xs)

let list_last xs = List.nth xs (List.length xs - 1)
