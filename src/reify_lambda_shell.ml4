(*i camlp4deps: "parsing/grammar.cma" i*)
(*i camlp4use: "pa_extend.cmo" i*)

open Reify_gen
open Reify_ext
open Plugin_utils

let contrib_name = "MirrorCore.Reify.Lambda"

module Std = Plugin_utils.Coqstd.Std
  (struct
    let contrib_name = contrib_name
   end)

module type REIFICATION =
sig
  type rpattern =
  | RIgnore
  | RHasType of Term.constr * rpattern
  | RConst
  | RGet   of int * rpattern
  | RApp   of rpattern * rpattern
  | RPi    of rpattern * rpattern
  | RLam   of rpattern * rpattern
  | RImpl  of rpattern * rpattern
  | RExact of Term.constr

  type command =
  | Patterns of Term.constr
  | Call of Term.constr
  | App of Term.constr
  | Abs of Term.constr * Term.constr
  | Var of Term.constr

  val add_pattern    : Term.constr -> Term.constr (* rpattern *) -> Term.constr -> unit
  val print_patterns : (Format.formatter -> unit -> unit) ->
    Format.formatter -> Term.constr -> unit

  val declare_syntax : Term.constr -> (Term.constr (* command *)) list -> unit
  val reify          : Term.constr -> Proof_type.goal Evd.sigma -> Term.constr -> Term.constr
  val reify_all      : Proof_type.goal Evd.sigma -> (Term.constr * Term.constr) list -> Term.constr list
end

module Reification : REIFICATION =
struct
  type reify_env =
  { env : Environ.env
  ; evm : Evd.evar_map
  ; bindings : bool list
  }

  (** [rule]s implement the pattern feature **)
  type 'a rule =
    ((int,int,reify_env) Term_match.pattern) *
      ('a -> (int, Term.constr) Hashtbl.t -> Term.constr)

  (** [reifier]s are the actual functions that get run **)
  type 'a reifier =
    'a -> Term.constr -> Term.constr array -> int -> Term.constr

  let pattern_table : (Term.constr, reify_env rule) Hashtbl.t = Hashtbl.create 5
  let reify_table : (Term.constr, reify_env reifier -> reify_env reifier) Hashtbl.t = Hashtbl.create 5

  let empty_array : Term.constr array = [| |]

  let reify_args (name : Term.constr) : reify_env reifier =
    let meta_reifier = Hashtbl.find reify_table name in
    let rec knot r =
      r (fun x -> knot r x)
    in
    knot meta_reifier

  let call_reify_term (r : reify_env reifier) gl trm =
    r gl trm empty_array (-1)

  let reify_term (name : Term.constr) =
    let meta_reifier = Hashtbl.find reify_table name in
    let rec knot r =
      r (fun x -> knot r x)
    in
    call_reify_term (knot meta_reifier)

  let reify (name : Term.constr) (gl : Proof_type.goal Evd.sigma) =
    let env = Tacmach.pf_env gl in
    let evar_map = Tacmach.project gl in
    reify_term name { env = env
		    ; evm = evar_map
		    ; bindings = [] }

  let reify_all gl ns_e =
    let env = Tacmach.pf_env gl in
    let evar_map = Tacmach.project gl in
    let st = { env = env
	     ; evm = evar_map
	     ; bindings = [] }
    in
    List.map (fun (ns,e) -> reify_term ns st e) ns_e



  let pattern_mod = ["MirrorCore";"Reify";"Patterns"]

  let ptrn_exact    = Std.resolve_symbol pattern_mod "RExact"
  let ptrn_const    = Std.resolve_symbol pattern_mod "RConst"
  let ptrn_ignore   = Std.resolve_symbol pattern_mod "RIgnore"
  let ptrn_get      = Std.resolve_symbol pattern_mod "RGet"
  let ptrn_app      = Std.resolve_symbol pattern_mod "RApp"
  let ptrn_pi       = Std.resolve_symbol pattern_mod "RPi"
  let ptrn_lam      = Std.resolve_symbol pattern_mod "RLam"
  let ptrn_impl     = Std.resolve_symbol pattern_mod "RImpl"
  let ptrn_has_type = Std.resolve_symbol pattern_mod "RHasType"

  let func_function = Std.resolve_symbol pattern_mod "function"
  let func_id       = Std.resolve_symbol pattern_mod "id"
(*  let act_get_store = Std.resolve_symbol pattern_mod "get_store" *)

  type rpattern =
  | RIgnore
  | RHasType of Term.constr * rpattern
  | RConst
  | RGet   of int * rpattern
  | RApp   of rpattern * rpattern
  | RPi    of rpattern * rpattern
  | RLam   of rpattern * rpattern
  | RImpl  of rpattern * rpattern
  | RExact of Term.constr

  let as_ignore s = Term_match.As (Term_match.Ignore, s)

  let into_rpattern gl =
    let rec into_rpattern (ptrn : Term.constr) : rpattern =
      Term_match.matches gl
	[ (Term_match.EGlob ptrn_ignore,
	   fun _ _ -> RIgnore)
	; (Term_match.App (Term_match.App (Term_match.EGlob ptrn_get,
					   Term_match.As (Term_match.Ignore, 0)),
			   Term_match.As (Term_match.Ignore, 1)),
	   fun _ s ->
	     let num  = Hashtbl.find s 0 in
	     let next = Hashtbl.find s 1 in
	     RGet (Std.of_nat num, into_rpattern next))
	; (Term_match.App (Term_match.App (Term_match.EGlob ptrn_exact,
					   Term_match.Ignore),
			   as_ignore 0),
	   fun _ s ->
	     let t = Hashtbl.find s 0 in
	     RExact t)
	; (Term_match.App (Term_match.App (Term_match.EGlob ptrn_app,
					   as_ignore 0),
			   as_ignore 1),
	   fun _ s ->
	     let f = Hashtbl.find s 0 in
	     let x = Hashtbl.find s 1 in
	     RApp (into_rpattern f, into_rpattern x))
	; (Term_match.App (Term_match.App (Term_match.EGlob ptrn_impl,
					   as_ignore 0),
			   as_ignore 1),
	   fun _ s ->
	     let f = Hashtbl.find s 0 in
	     let x = Hashtbl.find s 1 in
	     RImpl (into_rpattern f, into_rpattern x))
	; (Term_match.App (Term_match.App (Term_match.EGlob ptrn_pi,
					   as_ignore 0),
			   as_ignore 1),
	   fun _ s ->
	     let f = Hashtbl.find s 0 in
	     let x = Hashtbl.find s 1 in
	     RPi (into_rpattern f, into_rpattern x))
	; (Term_match.App (Term_match.App (Term_match.EGlob ptrn_lam,
					   as_ignore 0),
			   as_ignore 1),
	   fun _ s ->
	     let f = Hashtbl.find s 0 in
	     let x = Hashtbl.find s 1 in
	     RLam (into_rpattern f, into_rpattern x))
	; (Term_match.EGlob ptrn_const,
	   fun _ _ -> RConst)
	; (Term_match.App (Term_match.App (Term_match.EGlob ptrn_has_type,
					   as_ignore 0),
			   as_ignore 1),
	   fun _ s ->
	     let t = Hashtbl.find s 0 in
	     let x = Hashtbl.find s 1 in
	     RHasType (t, into_rpattern x))
	]
	ptrn
    in
    into_rpattern

  let rec app_full trm acc =
    match Term.kind_of_term trm with
      Term.App (f, xs) -> app_full f (Array.to_list xs @ acc)
    | _ -> (trm, acc)


  let compile_pattern (effects : (int, reify_env -> (int, Term.constr) Hashtbl.t -> reify_env) Hashtbl.t) =
    let fresh = ref (-1) in
    let rec compile_pattern (p : rpattern)
	(effect : (reify_env -> (int, Term.constr) Hashtbl.t -> reify_env) option)
	: (int,int,reify_env) Term_match.pattern * int list =
      match p with
	RExact g ->
	  (Term_match.EGlob g, [])
      | RIgnore -> (Term_match.Ignore, [])
      | RGet (i, p) ->
	let (p,us) = compile_pattern p effect in
	let _ =
	  match effect with
	    None -> ()
	  | Some eft -> Hashtbl.add effects i eft
	in
	(Term_match.As (p, i), i :: us)
      | RApp (p1, p2) ->
	let (p1,l1) = compile_pattern p1 effect in
	let (p2,l2) = compile_pattern p2 effect in
	(Term_match.App (p1,p2), l1 @ l2)
      | RConst ->
	let filter _ =
	  let rec filter trm =
	  (** TODO: This does not handle polymorphic types right now **)
	    let (f, args) = app_full trm [] in
	    Term.isConstruct f && List.for_all filter args
	  in
	  filter
	in
	(Term_match.Filter (filter, Term_match.Ignore),[])
      | RImpl (p1, p2) ->
	let (p1,l1) = compile_pattern p1 effect in
	let fresh =
	  let r = !fresh in
	  fresh := r - 1 ;
	  r
	in
	let new_effect =
	  match effect with
	    None ->
	      fun x s ->
		let nbindings = false :: x.bindings in
		let nenv =
		  Environ.push_rel (Names.Anonymous, None, Hashtbl.find s fresh)
		    x.env
		in
		{ x with bindings = nbindings ; env = nenv }
	  | Some eft ->
	    fun x s ->
	      let x = eft x s in
	      let nbindings = false :: x.bindings in
	      let nenv =
		Environ.push_rel (Names.Anonymous, None, Hashtbl.find s fresh)
		  x.env
	      in
	      { x with bindings = nbindings ; env = nenv }
	in
	let (p2,l2) = compile_pattern p2 (Some new_effect) in
	(Term_match.Impl (Term_match.As (p1,fresh),p2), l1 @ l2)
      | RPi (p1, p2) ->
	let (p1,l1) = compile_pattern p1 effect in
	let fresh =
	  let r = !fresh in
	  fresh := r - 1 ;
	  r
	in
	let new_effect =
	  match effect with
	    None ->
	      fun x s ->
		let nbindings = true :: x.bindings in
		let nenv =
		  Environ.push_rel (Names.Anonymous, None, Hashtbl.find s fresh)
		    x.env
		in
		{ x with bindings = nbindings ; env = nenv }
	  | Some eft ->
	    fun x s ->
	      let x = eft x s in
	      let nbindings = true :: x.bindings in
	      let nenv =
		Environ.push_rel (Names.Anonymous, None, Hashtbl.find s fresh)
		  x.env
	      in
	      { x with bindings = nbindings ; env = nenv }
	in
	let (p2,l2) = compile_pattern p2 (Some new_effect) in
	(Term_match.Pi (Term_match.As (p1,fresh),p2), l1 @ l2)
      | RHasType (t,p) ->
	let (p,l) = compile_pattern p effect in
	(Term_match.Filter
	   ((fun env trm ->
	     let ty = Typing.type_of env.env env.evm trm in
	     Term.eq_constr ty t), p), l)
(*
      | _ -> raise (Failure "unsupported")
*)
    in
    compile_pattern

  type action =
    Func of Term.constr
  | Id

  let parse_action gl : Term.constr -> action option =
    Term_match.matches gl
      [ (Term_match.App (Term_match.EGlob func_function, as_ignore 0),
	 fun _ s -> Some (Func (Hashtbl.find s 0)))
      ; (Term_match.App (Term_match.EGlob func_id, Term_match.Ignore),
	 fun _ s -> Some Id)
      ; (Term_match.Ignore, fun _ _ -> None)
      ]

  let compile_template (effects : (int, reify_env -> (int, Term.constr) Hashtbl.t -> reify_env) Hashtbl.t) =
    let rec compile_template (gl : unit) (tmp : Term.constr) (at : int)
	: Term.constr list -> reify_env -> (int, Term.constr) Hashtbl.t -> Term.constr =
      match Term.kind_of_term tmp with
	Term.Lambda (_, typ, body) ->
	  begin
	    match parse_action gl typ with
	      None ->
		let _ = Format.eprintf "Got Lambda, but didn't have action: %a" Std.pp_constr typ in
		fun ls _ _ ->
		  Term.substnl ls 0 tmp
	    | Some act ->
	      let rest = compile_template gl body (at + 1) in
	      let eft =
		try
		  Hashtbl.find effects at
		with
		  Not_found -> (fun x _ -> x)
	      in
	      match act with
	      | Func f ->
		fun vals gl s ->
		  let cur_val = Hashtbl.find s at in
		  rest ((reify_term f (eft gl s) cur_val) :: vals) gl s
	      | Id ->
		fun vals gl s ->
		  let cur_val = Hashtbl.find s at in
		  rest (cur_val :: vals) gl s
	  end
      | _ ->
	fun ls _ _ ->
	  Term.substnl ls 0 tmp
    in compile_template

  let parse_rule (gl : unit) (rule : Term.constr)
      (ptrn : Term.constr) (template : Term.constr)
  : reify_env rule =
    try
      let effects = Hashtbl.create 1 in
      let (ptrn, occs) = compile_pattern effects (into_rpattern gl ptrn) None in
      let action = compile_template effects gl template 0 [] in
      (ptrn, action)
    with
      Term_match.Match_failure -> raise (Failure "match failed, please report")

  let extend trm rul =
    Hashtbl.add pattern_table trm rul

  let add_pattern (name : Term.constr)
      (ptrn : Term.constr) (template : Term.constr)
  : unit =
    let rule = parse_rule () name ptrn template in
    extend name rule

  type command =
  | Patterns of Term.constr
  | Call of Term.constr
  | App of Term.constr
  | Abs of Term.constr * Term.constr
  | Var of Term.constr
(*  | Table of Term.constr *)

  let cmd_patterns = Std.resolve_symbol pattern_mod "Patterns"
  let cmd_call     = Std.resolve_symbol pattern_mod "Call"
  let cmd_app      = Std.resolve_symbol pattern_mod "App"
  let cmd_abs      = Std.resolve_symbol pattern_mod "Abs"
  let cmd_var      = Std.resolve_symbol pattern_mod "Var"

  let parse_command gl cmd =
    Term_match.matches gl
      [ (Term_match.App (Term_match.EGlob cmd_patterns, as_ignore 0),
	 fun _ s -> Patterns (Hashtbl.find s 0))
      ; (Term_match.App (Term_match.EGlob cmd_call, as_ignore 0),
	 fun _ s -> Call (Hashtbl.find s 0))
      ; (Term_match.App (Term_match.App (Term_match.EGlob cmd_app,
					 Term_match.Ignore),
			 as_ignore 0),
	 fun _ s -> App (Hashtbl.find s 0))
      ; (Term_match.App (Term_match.App (Term_match.EGlob cmd_var,
					 Term_match.Ignore),
			 as_ignore 0),
	 fun _ s -> Var (Hashtbl.find s 0))
      ; (Term_match.App (Term_match.App (Term_match.App (Term_match.EGlob cmd_abs,
							 as_ignore 1),
					 Term_match.Ignore),
			 as_ignore 0),
	 fun _ s -> Abs (Hashtbl.find s 1,Hashtbl.find s 0))
      ]
      cmd

  let rec compile_commands (ls : command list) : reify_env reifier -> reify_env reifier =
    match ls with
      [] ->
	fun top _ trm _ _ ->
	  let _ = Format.eprintf "Failed for: %a" Std.pp_constr trm in
	  raise (Failure "Failed")
    | l :: ls ->
      let k = compile_commands ls in
      match l with
      | Patterns i ->
	fun top gl trm args from ->
	  begin
	    try
	      Term_match.matches_app gl
		(Hashtbl.find_all pattern_table i)
		trm args from
	    with
	      Term_match.Match_failure -> k top gl trm args from
	  end
      | Call t ->
	fun top gl trm args from ->
	  reify_args t gl trm args from
      | Abs (ty_name,ctor) ->
	fun top gl trm args from ->
	  begin
	    if from = -1 then
	      match Term.kind_of_term trm with
		Term.Lambda (name, lhs, rhs) ->
		  let ty = reify_term ty_name gl lhs in
		  let new_gl =
		    { gl with
		      env = Environ.push_rel (name, None, lhs) gl.env
		    ; bindings = true :: gl.bindings
		    }
		  in
		  let body = call_reify_term top new_gl rhs in
		  Term.mkApp (ctor, [| ty ; body |])
	      | _ -> k top gl trm args from
	    else
	      k top gl trm args from
	  end
      | Var ctor ->
	fun top gl trm args from ->
	  begin
	    if from = -1 then
	      match Term.kind_of_term trm with
		Term.Rel i ->
		  let rec find ls i acc =
		    match ls with
		      [] -> assert false
		    | l :: ls ->
		      if i = 0 then
			(assert l ; acc)
		      else
			find ls (i - 1) (if l then acc + 1 else acc)
		  in
		  Term.mkApp (ctor, [| Std.to_nat (find gl.bindings (i-1) 0) |])
	      | _ -> k top gl trm args from
	    else
	      k top gl trm args from
	  end
      | App ctor ->
	fun top gl trm args from ->
	  begin
	    try
	      Term_match.matches_app gl
		[ (Term_match.App (as_ignore 0, as_ignore 1),
		   fun gl s ->
		     let f = call_reify_term top gl (Hashtbl.find s 0) in
		     let x = call_reify_term top gl (Hashtbl.find s 1) in
		     Term.mkApp (ctor, [| f ; x |]))
		]
		trm args from
	    with
	      Term_match.Match_failure -> k top gl trm args from
	  end

  let declare_syntax (name : Term.constr) (cmds : Term.constr list) : unit =
    let cmds = List.map (parse_command ()) cmds in
    let meta_reifier = compile_commands cmds in
    Hashtbl.replace reify_table name meta_reifier

  let rec print_rule out ptrn =
    Term_match.(
      match ptrn with
	Ignore -> Format.fprintf out "<any>"
      | As (a,i) -> Format.fprintf out "((%a) as %d)" print_rule a i
      | App (l,r) -> Format.fprintf out "(%a %@ %a)" print_rule l print_rule r
      | Impl (l,r) -> Format.fprintf out "(%a -> %a)" print_rule l print_rule r
      | Glob g -> Format.fprintf out "%a" Std.pp_constr (Lazy.force g)
      | EGlob g -> Format.fprintf out "%a" Std.pp_constr g
      | Lam (a,b,c) -> Format.fprintf out "(fun (%d : %a) => %a)" a print_rule b print_rule c
      | Ref i -> Format.fprintf out "<%d>" i
      | Choice ls -> Format.fprintf out "[...]"
      | Pi (a,b) -> Format.fprintf out "(Pi %a . %a)" print_rule a print_rule b
      | Filter (_,a) -> Format.fprintf out "(Filter - %a)" print_rule a)

  let apps = List.fold_right Pp.(++)

  let print_patterns sep out (name : Term.constr) : unit =
    try
      let vals = Hashtbl.find_all pattern_table name in
      List.iter (fun x -> Format.fprintf out "%a%a" sep () print_rule (fst x)) vals
    with
      Not_found -> Format.fprintf out "<none>"

end

let print_newline out () =
  Format.fprintf out "\n"


VERNAC COMMAND EXTEND Reify_Lambda_Shell_add_lang
  | [ "Reify" "Declare" "Syntax" constr(name) "{" constr_list(cmds) "}" ] ->
    [ let (evm,env) = Lemmas.get_current_context () in
      let name = Constrintern.interp_constr evm env name in
      let cmds = List.map (Constrintern.interp_constr evm env) cmds in
      Reification.declare_syntax name cmds ]
END;;

VERNAC COMMAND EXTEND Reify_Lambda_Shell_New_Pattern
  | [ "Reify" "Declare" "Patterns" constr(name) ] ->
    [ () ]
END;;


VERNAC COMMAND EXTEND Reify_Lambda_Shell_Add_Pattern
  | [ "Reify" "Pattern" constr(rule) "+=" constr(pattern) "=>" constr(template) ] ->
    [ try
	let (evm,env) = Lemmas.get_current_context () in
	let pattern   = Constrintern.interp_constr evm env pattern in
	let template  = Constrintern.interp_constr evm env template in
	let rule      = Constrintern.interp_constr evm env rule in
	Reification.add_pattern rule pattern template
      with
	Failure msg -> Pp.msgnl (Pp.str msg)
    ]
END;;

VERNAC COMMAND EXTEND Reify_Lambda_Shell_Print_Pattern
  | [ "Reify" "Print" "Patterns" constr(name) ] ->
    [ let (evm,env) = Lemmas.get_current_context () in
      let name   = Constrintern.interp_constr evm env name in
      let as_string = (** TODO: I don't really understand Ocaml's formatting **)
	let _ =
	  Format.fprintf Format.str_formatter "%a"
	    (Reification.print_patterns print_newline) name in
	Format.flush_str_formatter ()
      in
      Pp.(
      msgnl (   (str "Patterns for ")
	     ++ (Printer.pr_constr name)
	     ++ (str ":")
	     ++ (fnl ())
	     ++ (str as_string)))
    ]
END;;


(*
VERNAC COMMAND EXTEND Reify_Lambda_Shell_tables
  | [ "Reify:" "Declare" "Table" constr(name) ] ->
    [ () ]
  | [ "Reify:" "Table" constr(name) "+=" constr(key) "=>" constr(value) ] ->
    [ () ]
END;;
*)

TACTIC EXTEND Reify_Lambda_Shell_reify
  | ["reify_expr" constr(name) tactic(k) "[" ne_constr_list(es) "]" ] ->
    [ fun gl ->
        let env = Tacmach.pf_env gl in
	let evar_map = Tacmach.project gl in
	let res = Reification.reify_all gl (List.map (fun e -> (name,e)) es) in
	let ltac_args =
	  List.map
	    Plugin_utils.Use_ltac.to_ltac_val
	    res
	in
	Plugin_utils.Use_ltac.ltac_apply k ltac_args gl
    ]
END;;