open Ppxlib

type ops =
  { empty : Location.t -> expression
  ; add   : Location.t -> expression
  }

let rec translate ops expr =
  let loc = expr.pexp_loc in
  match expr with
  | [%expr () ] ->
    ops.empty loc

  | [%expr while [%e? test_expr] do [%e? body_expr] done ] ->
    [%expr
      let body () = [%e translate ops body_expr]
      and test () = [%e test_expr] in
      let rec loop accum =
        if test () then
          loop ([%e ops.add loc] accum (body ()))
        else
          accum
      in
      loop [%e ops.empty loc]
    ]

  | [%expr for [%p? pat] = [%e? init] to [%e? final] do [%e? body] done ] ->
     [%expr
       let body [%p pat] = [%e translate ops body] in
       let limit = [%e final] in
       let rec loop i accum =
         if i > limit then accum
         else loop (i+1) ([%e ops.add expr.pexp_loc] accum (body i))
       in
       loop [%e init] [%e ops.empty expr.pexp_loc]
     ]

  | [%expr for [%p? pat] = [%e? init] downto [%e? final] do [%e? body] done ] ->
     [%expr
        let body [%p pat] = [%e translate ops body] in
        let limit = [%e final] in
        let rec loop i accum =
          if i < limit then accum
          else loop (i-1) ([%e ops.add expr.pexp_loc] accum (body i))
        in
        loop [%e init] [%e ops.empty expr.pexp_loc]
     ]

  | [%expr [%e? expr1] ; [%e? expr2] ] ->
     let expr1 = translate ops expr1 in
     let expr2 = translate ops expr2 in
     [%expr [%e ops.add expr.pexp_loc] [%e expr1] [%e expr2]]

  | [%expr if [%e? expr1] then [%e? expr2] else [%e? expr3]] ->
     let expr2 = translate ops expr2 in
     let expr3 = translate ops expr3 in
     [%expr if [%e expr1] then [%e expr2] else [%e expr3]]

  | [%expr if [%e? expr1] then [%e? expr2]] ->
     let expr2 = translate ops expr2 in
     [%expr if [%e expr1] then [%e expr2] else [%e ops.empty loc]]

  | { pexp_desc = Pexp_match (expr, cases) } ->
     let cases =
       List.map
         (fun ({pc_rhs} as c) ->
            {c with pc_rhs=translate ops pc_rhs})
         cases
     in
     { expr with pexp_desc = Pexp_match (expr, cases) }

  | { pexp_desc = Pexp_let (recflag, bindings, body) } ->
     let body = translate ops body in
     {expr with pexp_desc=Pexp_let (recflag, bindings, body)}

  | { pexp_desc = Pexp_open (decl, expr) } ->
     let expr = translate ops expr in
     {expr with pexp_desc=Pexp_open (decl, expr)}

  | { pexp_desc = Pexp_letmodule (name, module_expr, expr) } ->
     let expr = translate ops expr in
     {expr with pexp_desc=Pexp_letmodule (name, module_expr, expr)}

  | expr ->
    expr

let expander ~loc:_ ~path:_ ~arg payload =
  let ops =
    match arg with
    | None ->
      { empty = (fun loc -> {[%expr empty] with pexp_loc=loc})
      ; add   = (fun loc -> {[%expr (^^)] with pexp_loc=loc})
      }
    | Some prefix ->
      let with_prefix ident loc =
        Ast_helper.Exp.ident ~loc (Ast.{ txt = Longident.Ldot (prefix.txt, ident); loc })
      in
      { empty = with_prefix "empty"
      ; add   = with_prefix "^^"
      }
  in
  translate ops payload

let rules =
  ["concat"; "concatenate"; "monoid"] |> List.map begin fun name ->
    Ppxlib.Context_free.Rule.extension  @@
    Extension.declare_with_path_arg
      name
      Extension.Context.Expression
      Ast_pattern.(single_expr_payload __)
      expander
  end

let () =
  Driver.register_transformation
    ~rules
    "ppx-monoid"
