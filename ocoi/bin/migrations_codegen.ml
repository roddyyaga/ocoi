open Core

let create ~up_sql ~down_sql ~name ~migrations_dir =
  let ( / ) = Filename.concat in
  let up_path = migrations_dir / "up" in
  let down_path = migrations_dir / "down" in
  let filename =
    let timestamp = Unix.(strftime (time () |> gmtime) "%Y%m%dT%H%M%SZ") in
    Printf.sprintf "%s_%s.sql" timestamp name
  in
  Out_channel.write_all ~data:up_sql (up_path / filename);
  Out_channel.write_all ~data:down_sql (down_path / filename)
