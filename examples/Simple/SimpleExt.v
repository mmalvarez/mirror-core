Require Import MirrorCore.syms.SymEnv.
Require Import MirrorCore.syms.SymSum.
Require McExamples.Simple.Simple.

Definition func := sum Simple.func SymEnv.func.

Instance RSym_func fs : SymI.RSym func :=
  @SymSum.RSym_sum Simple.typ _ Simple.func SymEnv.func _
                   (@SymEnv.RSym_func Simple.typ _ fs).

Require Import MirrorCore.Reify.Reify.
Require Import MirrorCore.Lambda.ExprCore.

(** Declare patterns **)
Reify Declare Patterns patterns_simple_typ := Simple.typ.
Reify Declare Patterns patterns_simple := (expr Simple.typ func).

Reify Declare Syntax reify_simple_typ :=
{ (@Patterns _ patterns_simple_typ (@Fail Simple.typ)) }.

Reify Declare Typed Table table_terms : BinNums.positive => reify_simple_typ.

Let typ := Simple.typ.
Let other x := @Inj typ func (inr x).
Print Patterns.TypedTable.

(** Declare syntax **)
Reify Declare Syntax reify_simple :=
{ (@Patterns.Patterns _ patterns_simple
  (@Patterns.App _ (@ExprCore.App typ func)
  (@Patterns.Abs (expr typ func) reify_simple_typ (@ExprCore.Abs typ func)
  (@Patterns.Var (expr typ func) (@ExprCore.Var typ func)
  (@Patterns.TypedTable (expr typ func) BinNums.positive reify_simple_typ table_terms other
  (@Patterns.Fail (expr typ func)))))))
}.

Reify Pattern patterns_simple_typ += (@RExact _ nat)  => Simple.tyNat.
Reify Pattern patterns_simple_typ += (@RExact _ bool) => Simple.tyBool.
Reify Pattern patterns_simple_typ += (@RExact _ Prop) => Simple.tyProp.
Reify Pattern patterns_simple_typ += (@RImpl (@RGet 0 RIgnore) (@RGet 1 RIgnore)) => (fun (a b : function reify_simple_typ) => Simple.tyArr a b).

Reify Pattern patterns_simple += (@RGet 0 RConst) => (fun (n : id nat) => @Inj typ func (inl (Simple.N n))).
Reify Pattern patterns_simple += (RApp (RApp (@RExact _ plus) (RGet 0 RIgnore)) (RGet 1 RIgnore)) => (fun (a b : function reify_simple) => App (App (Inj (inl Simple.Plus)) a) b).
Reify Pattern patterns_simple += (RApp (RApp (@RExact _ NPeano.ltb) (RGet 0 RIgnore)) (RGet 1 RIgnore)) => (fun (a b : function reify_simple) => App (App (Inj (inl Simple.Lt)) a) b).
Reify Pattern patterns_simple += (RApp (RApp (RApp (@RExact _ (@eq)) (RGet 0 RIgnore)) (RGet 1 RIgnore)) (RGet 2 RIgnore)) => (fun (t : function reify_simple_typ) (a b : function reify_simple) => App (App (Inj (inl (Simple.Eq t))) a) b).

Let map_ctor (a : Simple.typ) (b : TypesI.typD nil a) :=
  @SymEnv.F Simple.typ _ a (fun ts => b).

Ltac reify_typ trm :=
  let k e :=
      refine e
  in
  reify_expr reify_simple_typ k [ True ] [ trm ].

Ltac reify trm :=
  let k e :=
      refine e
  in
  reify_expr reify_simple k [ (fun x : mk_dvar_map table_term (True ] [ trm ].

Definition test_1 : expr typ func.
  pose (x := 0).
  reify (0 = x).
Defined.
Print test_1.