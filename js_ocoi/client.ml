open Specification
module Fetch = Ezjs_fetch_lwt

module Make = struct
  module Specifications = struct
    module type None = sig
      include S_base

      module Parameters : Parameters.None
    end

    module type Json = sig
      include S_base

      module Parameters : Parameters.Json
    end

    module Path = struct
      module type One = sig
        include S_base

        module Parameters : Parameters.Path.One
      end
    end
  end

  module None (S : Specifications.None) = struct
    let f () = Fetch.fetch ~meth:(verb_to_string S.verb) S.path Fetch.to_text
  end

  module Json (S : Specifications.Json) = struct
    let f t =
      let body =
        Fetch.RString (Yojson.Safe.to_string (S.Parameters.yojson_of_t t))
      in
      Fetch.fetch ~meth:(verb_to_string S.verb) ~body S.path Fetch.to_text
  end

  module Path = struct
    let get_one_param_name (module S : Specifications.Path.One) =
      let () =
        assert (
          S.path |> Utils.explode_string
          |> Utils.list_count (Char.equal ':')
          = 1 )
      in
      (* TODO - replace with JS regexes *)
      let pattern = Str.regexp {|.*:\([^/]*\)\(/\|$\)|} in
      if Str.string_match pattern S.path 0 then Str.matched_group 1 S.path
      else assert false

    module One (S : Specifications.Path.One) = struct
      let name = get_one_param_name (module S)

      let f t =
        let param = S.Parameters.to_string t in
        let path_with_param =
          Str.replace_first (Str.regexp (Str.quote (":" ^ name))) param S.path
        in
        Fetch.fetch ~meth:(verb_to_string S.verb) path_with_param Fetch.to_text
    end
  end
end
