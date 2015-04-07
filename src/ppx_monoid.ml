open Asttypes
open Parsetree
open Ast_mapper
open Ast_helper

let split_extension_name str =
  match String.index str '.' with
    | exception Not_found ->
       (str, None)
    | i ->
       let extension_name  = String.sub str 0 i in
       let module_path_str = String.sub str (i+1) (String.length str - i - 1) in
       let module_path     = Longident.parse module_path_str in
       (* FIXME: check that ident is lexically a valid module-path.
          Otherwise the user gets weird error messages *)
       (extension_name, Some module_path)

type ops =
  { empty : Location.t -> expression
  ; add   : Location.t -> expression
  }

let rec translate ops mapper expr = match expr.pexp_desc with
  | Pexp_construct ({txt=Longident.Lident "()"}, None) ->
     ops.empty expr.pexp_loc

  | Pexp_sequence (expr1, expr2) ->
     let expr1 = translate ops mapper expr1 in
     let expr2 = translate ops mapper expr2 in
     [%expr [%e ops.add expr.pexp_loc] [%e expr1] [%e expr2]]

  | Pexp_ifthenelse (expr1, expr2, expr3) ->
     let expr1 = map_expr mapper expr1 in
     let expr2 = translate ops mapper expr2 in
     (match expr3 with
       | None ->
          [%expr if [%e expr1] then [%e expr2]
                 else [%e ops.empty expr.pexp_loc]]
       | Some expr3 ->
          let expr3 = translate ops mapper expr3 in
          [%expr if [%e expr1] then [%e expr2] else [%e expr3]])

  | Pexp_match (expr, cases) ->
     let expr = map_expr mapper expr in
     let cases =
       List.map
         (fun ({pc_rhs} as c) ->
            {c with pc_rhs=translate ops mapper pc_rhs})
         cases
     in
     { expr with pexp_desc = Pexp_match (expr, cases) }

  | Pexp_let (recflag, bindings, body) ->
     let bindings =
       List.map
         (fun vb -> {vb with pvb_expr=map_expr mapper vb.pvb_expr})
         bindings
     and body = translate ops mapper body
     in
     {expr with pexp_desc=Pexp_let (recflag, bindings, body)}

  | _ ->
     map_expr mapper expr

and map_expr mapper expr = match expr.pexp_desc with
  | Pexp_extension ({txt}, PStr [{pstr_desc=Pstr_eval (expr, _)}]) ->
     (match split_extension_name txt with
       | "monoid", None ->
          let ops =
            { empty = (fun loc -> {[%expr empty] with pexp_loc=loc})
            ; add   = (fun loc -> {[%expr (^^)] with pexp_loc=loc})
            }
          in
          translate ops mapper expr

       | "monoid", Some prefix ->
          let with_prefix ident loc =
            Exp.ident ~loc
              (Location.mkloc (Longident.Ldot (prefix, ident)) loc)
          in
          let ops =
            { empty = with_prefix "empty"
            ; add   = with_prefix "^^"
            }
          in
          translate ops mapper expr

       | _, _ ->
          default_mapper.expr mapper expr)

  | _ ->
     default_mapper.expr mapper expr

let _ =
  register "ppx_monoid" (fun _ -> {default_mapper with expr = map_expr})
