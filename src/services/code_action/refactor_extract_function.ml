(*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

(* Collect all statements that are completely within the selection. *)
class statements_collector (extract_range : Loc.t) =
  object (this)
    inherit [Loc.t] Flow_ast_mapper.mapper as super

    val mutable _collected_statements = Some []

    method private collect_statement stmt =
      _collected_statements <-
        (match _collected_statements with
        | None -> None
        | Some acc -> Some (stmt :: acc))

    (* `Some collected_statements`, None` when extraction is not allowed based on user selection. *)
    method collected_statements () =
      match _collected_statements with
      | Some collected_statements -> Some (List.rev collected_statements)
      | None -> None

    method! statement stmt =
      let (statement_loc, _) = stmt in
      if Loc.contains extract_range statement_loc then
        let () = this#collect_statement stmt in
        (* If the statement is already completely contained in the range, do not recursve deeper
           to collect more nested ones. *)
        stmt
      else if Loc.contains statement_loc extract_range then
        (* If the range is completely contained in the statement,
           we should recursve deeper to find smaller nested statements that are contained in the range. *)
        super#statement stmt
      else if Loc.intersects extract_range statement_loc then
        (* When there is intersection, it means that the selection is not allowed for extraction. *)
        let () = _collected_statements <- None in
        stmt
      else
        (* If disjoint, the statement and nested ones do not need to be collected. *)
        stmt
  end

let union_loc acc loc =
  match acc with
  | None -> Some loc
  | Some existing_loc -> Some (Loc.btwn existing_loc loc)

class new_function_call_replacer insert_new_function_call_loc rest_statements_loc_union =
  object (this)
    inherit [Loc.t] Flow_ast_mapper.mapper as super

    method private should_be_replaced_by_function_call loc =
      Loc.equal insert_new_function_call_loc loc

    method private inserted_function_call_loc () =
      match rest_statements_loc_union with
      | None -> insert_new_function_call_loc
      | Some rest_union -> Loc.btwn insert_new_function_call_loc rest_union

    method private should_be_replaced_by_empty loc =
      match rest_statements_loc_union with
      | Some rest_statements_loc_union -> Loc.contains rest_statements_loc_union loc
      | None -> false

    method! statement_fork_point stmt =
      let (statement_loc, _) = stmt in
      let open Ast_builder in
      if this#should_be_replaced_by_function_call statement_loc then
        [
          Statements.expression
            ~loc:(this#inserted_function_call_loc ())
            (Expressions.call (Expressions.identifier "newFunction"));
        ]
      else if this#should_be_replaced_by_empty statement_loc then
        []
      else
        super#statement_fork_point stmt
  end

let extract_statements ast extract_range =
  let collector = new statements_collector extract_range in
  let _ = collector#program ast in
  collector#collected_statements ()

let create_extracted_function statements =
  let id = Some (Ast_builder.Identifiers.identifier "newFunction") in
  (* TODO: add parameters from locally undefined variables within statements *)
  let params = Ast_builder.Functions.params [] in
  let body = Ast_builder.Functions.body statements in
  (* TODO: make it async if body contains await *)
  (* TODO: make it a generator if body contains yield *)
  Ast_builder.Functions.make ~id ~params ~body ()

let insert_function_to_toplevel (program_loc, program) extracted_statements =
  (* Put extracted function to two lines after the end of program to have nice format. *)
  let new_function_loc = Loc.(cursor program_loc.source (program_loc._end.line + 2) 0) in
  ( program_loc,
    Flow_ast.Program.
      {
        program with
        statements =
          program.statements
          @ [
              ( new_function_loc,
                Flow_ast.Statement.FunctionDeclaration
                  (create_extracted_function extracted_statements) );
            ];
      } )

let provide_available_refactor ast extract_range =
  match extract_statements ast extract_range with
  | None -> None
  | Some extracted_statements ->
    let extracted_statements_locations = List.map fst extracted_statements in
    (match extracted_statements_locations with
    | [] -> None
    | insert_new_function_call_loc :: rest_statements_locations ->
      let rest_statements_loc_union = List.fold_left union_loc None rest_statements_locations in
      let replacer =
        new new_function_call_replacer insert_new_function_call_loc rest_statements_loc_union
      in
      Some (insert_function_to_toplevel (replacer#program ast) extracted_statements))
