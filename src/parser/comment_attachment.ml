(*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

module Ast = Flow_ast
open Flow_ast
open Parser_env

let id = Flow_ast_mapper.id

let id_list_last (map : 'a -> 'a) (lst : 'a list) : 'a list =
  match List.rev lst with
  | [] -> lst
  | hd :: tl ->
    let hd' = map hd in
    if hd == hd' then
      lst
    else
      List.rev (hd' :: tl)

(* Mapper that removes all trailing comments that appear after a given position in an AST node *)
class ['loc] trailing_comments_remover ~after_pos =
  object (this)
    inherit ['loc] Flow_ast_mapper.mapper

    method! syntax comments =
      let open Syntax in
      let { trailing; _ } = comments in
      let trailing' =
        List.filter (fun (loc, _) -> Loc.(pos_cmp loc.start after_pos < 0)) trailing
      in
      if List.length trailing = List.length trailing' then
        comments
      else
        { comments with trailing = trailing' }

    method! array _loc expr =
      let open Ast.Expression.Array in
      let { comments; _ } = expr in
      id this#syntax_opt comments expr (fun comments' -> { expr with comments = comments' })

    method! assignment _loc expr =
      let open Ast.Expression.Assignment in
      let { right; comments; _ } = expr in
      let right' = this#expression right in
      let comments' = this#syntax_opt comments in
      if right == right' && comments == comments' then
        expr
      else
        { expr with right = right'; comments = comments' }

    method! binary _loc expr =
      let open Ast.Expression.Binary in
      let { right; comments; _ } = expr in
      let right' = this#expression right in
      let comments' = this#syntax_opt comments in
      if right == right' && comments == comments' then
        expr
      else
        { expr with right = right'; comments = comments' }

    method! block _loc stmt =
      let open Ast.Statement.Block in
      let { comments; _ } = stmt in
      id this#syntax_opt comments stmt (fun comments' -> { stmt with comments = comments' })

    method! call _annot expr =
      let open Ast.Expression.Call in
      let { comments; _ } = expr in
      id this#syntax_opt comments expr (fun comments' -> { expr with comments = comments' })

    method! class_ _loc cls =
      let open Ast.Class in
      let { body; comments; _ } = cls in
      let body' = this#class_body body in
      let comments' = this#syntax_opt comments in
      if body == body' && comments == comments' then
        cls
      else
        { cls with body = body'; comments = comments' }

    method! class_body body = body

    method! conditional _loc expr =
      let open Ast.Expression.Conditional in
      let { alternate; comments; _ } = expr in
      let alternate' = this#expression alternate in
      let comments' = this#syntax_opt comments in
      if alternate == alternate' && comments = comments' then
        expr
      else
        { expr with alternate = alternate'; comments = comments' }

    method! function_ _loc func =
      let open Ast.Function in
      let { body; comments; _ } = func in
      let body' = this#function_body_any body in
      let comments' = this#syntax_opt comments in
      if body == body' && comments == comments' then
        func
      else
        { func with body = body'; comments = comments' }

    method! import _loc expr =
      let open Ast.Expression.Import in
      let { comments; _ } = expr in
      id this#syntax_opt comments expr (fun comments' -> { expr with comments = comments' })

    method! jsx_element _loc elem =
      let open Ast.JSX in
      let { comments; _ } = elem in
      id this#syntax_opt comments elem (fun comments' -> { elem with comments = comments' })

    method! jsx_fragment _loc frag =
      let open Ast.JSX in
      let { frag_comments = comments; _ } = frag in
      id this#syntax_opt comments frag (fun comments' -> { frag with frag_comments = comments' })

    method! logical _loc expr =
      let open Ast.Expression.Logical in
      let { right; comments; _ } = expr in
      let right' = this#expression right in
      let comments' = this#syntax_opt comments in
      if right == right' && comments == comments' then
        expr
      else
        { expr with right = right'; comments = comments' }

    method! new_ _loc expr =
      let open Ast.Expression.New in
      let { comments; _ } = expr in
      id this#syntax_opt comments expr (fun comments' -> { expr with comments = comments' })

    method! member _loc expr =
      let open Ast.Expression.Member in
      let { property; comments; _ } = expr in
      let property' = this#member_property property in
      let comments' = this#syntax_opt comments in
      if property == property' && comments == comments' then
        expr
      else
        { expr with property = property'; comments = comments' }

    method! object_ _loc expr =
      let open Ast.Expression.Object in
      let { comments; _ } = expr in
      id this#syntax_opt comments expr (fun comments' -> { expr with comments = comments' })

    method! object_type _loc obj =
      let open Ast.Type.Object in
      let { comments; _ } = obj in
      id this#syntax_opt comments obj (fun comments' -> { obj with comments = comments' })

    method! sequence _loc expr =
      let open Ast.Expression.Sequence in
      let { expressions; comments } = expr in
      let expressions' = id_list_last this#expression expressions in
      let comments' = this#syntax_opt comments in
      if expressions == expressions' && comments == comments' then
        expr
      else
        { expressions = expressions'; comments = comments' }

    method! template_literal _loc expr =
      let open Ast.Expression.TemplateLiteral in
      let { comments; _ } = expr in
      id this#syntax_opt comments expr (fun comments' -> { expr with comments = comments' })

    method! type_cast _loc expr =
      let open Ast.Expression.TypeCast in
      let { comments; _ } = expr in
      id this#syntax_opt comments expr (fun comments' -> { expr with comments = comments' })
  end

let mk_remover_after_last_loc env =
  let open Loc in
  match Parser_env.last_loc env with
  | None -> None
  | Some { _end; _ } -> Some (new trailing_comments_remover ~after_pos:_end)

let mk_remover_after_last_line env =
  let open Loc in
  match Parser_env.last_loc env with
  | None -> None
  | Some { _end = { line; _ }; _ } ->
    let next_line_start = { line = line + 1; column = 0 } in
    Some (new trailing_comments_remover ~after_pos:next_line_start)

let apply_remover remover node f =
  match remover with
  | None -> node
  | Some remover -> f remover node

(* Returns a remover function which removes comments beginning after the previous token. *)
let remover_after_last_loc env =
  let remover =
    if Peek.comments env <> [] then
      mk_remover_after_last_loc env
    else
      None
  in
  apply_remover remover

(* Consumes and returns comments on the same line as the previous token. Also returns a remover
   function which can be used to remove comments beginning after the previous token's line. *)
let trailing_and_remover_after_last_line env =
  let trailing = Eat.comments_until_next_line env in
  let remover =
    if trailing <> Peek.comments env then
      mk_remover_after_last_line env
    else
      None
  in
  (trailing, apply_remover remover)
