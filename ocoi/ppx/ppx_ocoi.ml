open Base
open Ppxlib
module Buildef = Ast_builder.Default

let is_id_field field =
  match field with { pld_name = { txt = "id"; _ }; _ } -> true | _ -> false

let is_ocoi_deriver exp =
  match exp with
  | { pexp_desc = Pexp_ident { txt = Lident s; _ }; _ } -> (
      match s with "ocoi" -> true | _ -> false )
  | _ -> false

[%%if ocaml_version >= (4, 07, 0)]

let remove_ppx_ocoi_deriver ptype_attributes =
  let f { attr_name; attr_payload; attr_loc } =
    match (attr_name, attr_payload) with
    | ( ({ txt = "deriving"; _ } as name),
        PStr
          [
            ( {
                pstr_desc =
                  Pstr_eval
                    ( ({ pexp_desc = Pexp_tuple exps; _ } as eval_contents),
                      eval_other );
                _;
              } as str );
          ] ) -> (
        let new_exps = List.filter ~f:(fun e -> not (is_ocoi_deriver e)) exps in
        match List.length new_exps with
        | 0 -> None
        | _ ->
            let new_deriving_arg =
              match new_exps with
              | [ x ] -> x
              | _ -> { eval_contents with pexp_desc = Pexp_tuple new_exps }
            in
            let new_payload =
              PStr
                [
                  {
                    str with
                    pstr_desc = Pstr_eval (new_deriving_arg, eval_other);
                  };
                ]
            in
            Some { attr_name = name; attr_payload = new_payload; attr_loc } )
    | _other -> Some { attr_name; attr_payload; attr_loc }
  in
  List.filter_map ~f ptype_attributes

[%%else]

let remove_ppx_ocoi_deriver ptype_attributes =
  let f attribute =
    match attribute with
    | ( ({ txt = "deriving"; _ } as name),
        PStr
          [
            ( {
                pstr_desc =
                  Pstr_eval
                    ( ({ pexp_desc = Pexp_tuple exps; _ } as eval_contents),
                      eval_other );
                _;
              } as str );
          ] ) -> (
        let new_exps = List.filter ~f:(fun e -> not (is_ocoi_deriver e)) exps in
        match List.length new_exps with
        | 0 -> None
        | _ ->
            let new_deriving_arg =
              match new_exps with
              | [ x ] -> x
              | _ -> { eval_contents with pexp_desc = Pexp_tuple new_exps }
            in
            Some
              ( name,
                PStr
                  [
                    {
                      str with
                      pstr_desc = Pstr_eval (new_deriving_arg, eval_other);
                    };
                  ] ) )
    | other -> Some other
  in
  List.filter_map ~f ptype_attributes

[%%endif]

let process_decl decl =
  let fields, type_name, loc =
    match decl with
    | { ptype_name = { txt; loc }; ptype_kind = Ptype_record fields; _ } ->
        (fields, txt, loc)
    | _ -> failwith "ppx_ocoi only defined for record types"
  in
  match List.exists ~f:is_id_field fields with
  | false -> None
  | true ->
      let new_name = type_name ^ "_no_id" in
      let new_fields =
        List.filter ~f:(fun field -> not (is_id_field field)) fields
      in
      Some
        {
          decl with
          ptype_kind = Ptype_record new_fields;
          ptype_name = { txt = new_name; loc };
          ptype_attributes = remove_ppx_ocoi_deriver decl.ptype_attributes;
        }

let remove_id_field ptype_record_fields =
  let f field = not (is_id_field field) in
  List.filter ~f ptype_record_fields

let expand_str ~loc ~path:_ (rec_flag, decls) =
  let processed_decls = List.filter_map ~f:process_decl decls in
  [ { pstr_desc = Pstr_type (rec_flag, processed_decls); pstr_loc = loc } ]

let str_generator = Deriving.Generator.make_noarg expand_str

let deriver = Deriving.add ~str_type_decl:str_generator "ocoi"
