open! Ppx_yojson_conv_lib.Yojson_conv.Primitives
type t = {
  id: int ;
  name: string ;
  cool: bool ;
  another_id: int }[@@deriving (yojson, ocoi)]
include
  struct
    let _ = fun (_ : t) -> ()
    let t_of_yojson =
      (let _tp_loc = "test.ml.t" in
       function
       | `Assoc field_yojsons as yojson ->
           let id_field = ref None
           and name_field = ref None
           and cool_field = ref None
           and another_id_field = ref None
           and duplicates = ref []
           and extra = ref [] in
           let rec iter =
             function
             | (field_name, _field_yojson)::tail ->
                 ((match field_name with
                   | "id" ->
                       (match Ppx_yojson_conv_lib.(!) id_field with
                        | None ->
                            let fvalue = int_of_yojson _field_yojson in
                            id_field := (Some fvalue)
                        | Some _ ->
                            duplicates := (field_name ::
                              (Ppx_yojson_conv_lib.(!) duplicates)))
                   | "name" ->
                       (match Ppx_yojson_conv_lib.(!) name_field with
                        | None ->
                            let fvalue = string_of_yojson _field_yojson in
                            name_field := (Some fvalue)
                        | Some _ ->
                            duplicates := (field_name ::
                              (Ppx_yojson_conv_lib.(!) duplicates)))
                   | "cool" ->
                       (match Ppx_yojson_conv_lib.(!) cool_field with
                        | None ->
                            let fvalue = bool_of_yojson _field_yojson in
                            cool_field := (Some fvalue)
                        | Some _ ->
                            duplicates := (field_name ::
                              (Ppx_yojson_conv_lib.(!) duplicates)))
                   | "another_id" ->
                       (match Ppx_yojson_conv_lib.(!) another_id_field with
                        | None ->
                            let fvalue = int_of_yojson _field_yojson in
                            another_id_field := (Some fvalue)
                        | Some _ ->
                            duplicates := (field_name ::
                              (Ppx_yojson_conv_lib.(!) duplicates)))
                   | _ ->
                       if
                         Ppx_yojson_conv_lib.(!)
                           Ppx_yojson_conv_lib.Yojson_conv.record_check_extra_fields
                       then
                         extra := (field_name ::
                           (Ppx_yojson_conv_lib.(!) extra))
                       else ());
                  iter tail)
             | [] -> () in
           (iter field_yojsons;
            (match Ppx_yojson_conv_lib.(!) duplicates with
             | _::_ ->
                 Ppx_yojson_conv_lib.Yojson_conv_error.record_duplicate_fields
                   _tp_loc (Ppx_yojson_conv_lib.(!) duplicates) yojson
             | [] ->
                 (match Ppx_yojson_conv_lib.(!) extra with
                  | _::_ ->
                      Ppx_yojson_conv_lib.Yojson_conv_error.record_extra_fields
                        _tp_loc (Ppx_yojson_conv_lib.(!) extra) yojson
                  | [] ->
                      (match ((Ppx_yojson_conv_lib.(!) id_field),
                               (Ppx_yojson_conv_lib.(!) name_field),
                               (Ppx_yojson_conv_lib.(!) cool_field),
                               (Ppx_yojson_conv_lib.(!) another_id_field))
                       with
                       | (Some id_value, Some name_value, Some cool_value,
                          Some another_id_value) ->
                           {
                             id = id_value;
                             name = name_value;
                             cool = cool_value;
                             another_id = another_id_value
                           }
                       | _ ->
                           Ppx_yojson_conv_lib.Yojson_conv_error.record_undefined_elements
                             _tp_loc yojson
                             [((Ppx_yojson_conv_lib.poly_equal
                                  (Ppx_yojson_conv_lib.(!) id_field) None),
                                "id");
                             ((Ppx_yojson_conv_lib.poly_equal
                                 (Ppx_yojson_conv_lib.(!) name_field) None),
                               "name");
                             ((Ppx_yojson_conv_lib.poly_equal
                                 (Ppx_yojson_conv_lib.(!) cool_field) None),
                               "cool");
                             ((Ppx_yojson_conv_lib.poly_equal
                                 (Ppx_yojson_conv_lib.(!) another_id_field)
                                 None), "another_id")]))))
       | _ as yojson ->
           Ppx_yojson_conv_lib.Yojson_conv_error.record_list_instead_atom
             _tp_loc yojson : Ppx_yojson_conv_lib.Yojson.Safe.t -> t)
    let _ = t_of_yojson
    let yojson_of_t =
      (function
       | { id = v_id; name = v_name; cool = v_cool; another_id = v_another_id
           } ->
           let bnds : (string * Ppx_yojson_conv_lib.Yojson.Safe.t) list = [] in
           let bnds =
             let arg = yojson_of_int v_another_id in ("another_id", arg) ::
               bnds in
           let bnds =
             let arg = yojson_of_bool v_cool in ("cool", arg) :: bnds in
           let bnds =
             let arg = yojson_of_string v_name in ("name", arg) :: bnds in
           let bnds = let arg = yojson_of_int v_id in ("id", arg) :: bnds in
           `Assoc bnds : t -> Ppx_yojson_conv_lib.Yojson.Safe.t)
    let _ = yojson_of_t
    type t_no_id = {
      name: string ;
      cool: bool ;
      another_id: int }[@@deriving yojson]
    include
      struct
        let _ = fun (_ : t_no_id) -> ()
        let t_no_id_of_yojson =
          (let _tp_loc = "test.ml.t_no_id" in
           function
           | `Assoc field_yojsons as yojson ->
               let name_field = ref None
               and cool_field = ref None
               and another_id_field = ref None
               and duplicates = ref []
               and extra = ref [] in
               let rec iter =
                 function
                 | (field_name, _field_yojson)::tail ->
                     ((match field_name with
                       | "name" ->
                           (match Ppx_yojson_conv_lib.(!) name_field with
                            | None ->
                                let fvalue = string_of_yojson _field_yojson in
                                name_field := (Some fvalue)
                            | Some _ ->
                                duplicates := (field_name ::
                                  (Ppx_yojson_conv_lib.(!) duplicates)))
                       | "cool" ->
                           (match Ppx_yojson_conv_lib.(!) cool_field with
                            | None ->
                                let fvalue = bool_of_yojson _field_yojson in
                                cool_field := (Some fvalue)
                            | Some _ ->
                                duplicates := (field_name ::
                                  (Ppx_yojson_conv_lib.(!) duplicates)))
                       | "another_id" ->
                           (match Ppx_yojson_conv_lib.(!) another_id_field
                            with
                            | None ->
                                let fvalue = int_of_yojson _field_yojson in
                                another_id_field := (Some fvalue)
                            | Some _ ->
                                duplicates := (field_name ::
                                  (Ppx_yojson_conv_lib.(!) duplicates)))
                       | _ ->
                           if
                             Ppx_yojson_conv_lib.(!)
                               Ppx_yojson_conv_lib.Yojson_conv.record_check_extra_fields
                           then
                             extra := (field_name ::
                               (Ppx_yojson_conv_lib.(!) extra))
                           else ());
                      iter tail)
                 | [] -> () in
               (iter field_yojsons;
                (match Ppx_yojson_conv_lib.(!) duplicates with
                 | _::_ ->
                     Ppx_yojson_conv_lib.Yojson_conv_error.record_duplicate_fields
                       _tp_loc (Ppx_yojson_conv_lib.(!) duplicates) yojson
                 | [] ->
                     (match Ppx_yojson_conv_lib.(!) extra with
                      | _::_ ->
                          Ppx_yojson_conv_lib.Yojson_conv_error.record_extra_fields
                            _tp_loc (Ppx_yojson_conv_lib.(!) extra) yojson
                      | [] ->
                          (match ((Ppx_yojson_conv_lib.(!) name_field),
                                   (Ppx_yojson_conv_lib.(!) cool_field),
                                   (Ppx_yojson_conv_lib.(!) another_id_field))
                           with
                           | (Some name_value, Some cool_value, Some
                              another_id_value) ->
                               {
                                 name = name_value;
                                 cool = cool_value;
                                 another_id = another_id_value
                               }
                           | _ ->
                               Ppx_yojson_conv_lib.Yojson_conv_error.record_undefined_elements
                                 _tp_loc yojson
                                 [((Ppx_yojson_conv_lib.poly_equal
                                      (Ppx_yojson_conv_lib.(!) name_field)
                                      None), "name");
                                 ((Ppx_yojson_conv_lib.poly_equal
                                     (Ppx_yojson_conv_lib.(!) cool_field)
                                     None), "cool");
                                 ((Ppx_yojson_conv_lib.poly_equal
                                     (Ppx_yojson_conv_lib.(!)
                                        another_id_field) None),
                                   "another_id")]))))
           | _ as yojson ->
               Ppx_yojson_conv_lib.Yojson_conv_error.record_list_instead_atom
                 _tp_loc yojson : Ppx_yojson_conv_lib.Yojson.Safe.t ->
                                    t_no_id)
        let _ = t_no_id_of_yojson
        let yojson_of_t_no_id =
          (function
           | { name = v_name; cool = v_cool; another_id = v_another_id } ->
               let bnds : (string * Ppx_yojson_conv_lib.Yojson.Safe.t) list =
                 [] in
               let bnds =
                 let arg = yojson_of_int v_another_id in ("another_id", arg)
                   :: bnds in
               let bnds =
                 let arg = yojson_of_bool v_cool in ("cool", arg) :: bnds in
               let bnds =
                 let arg = yojson_of_string v_name in ("name", arg) :: bnds in
               `Assoc bnds : t_no_id -> Ppx_yojson_conv_lib.Yojson.Safe.t)
        let _ = yojson_of_t_no_id
      end[@@ocaml.doc "@inline"][@@merlin.hide ]
  end[@@ocaml.doc "@inline"][@@merlin.hide ]
