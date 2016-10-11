(* PolyQuantPullRtac.v
 * Rtac implementation of existential quantifier puller, which can "pull"
 * quantifiers out of and'd expressions to the front.
 * Testbed for the second-class polymorphism mechanism.
 *)
Require Import ExtLib.Core.RelDec.
Require Import ExtLib.Tactics.
Require Import MirrorCore.Util.Compat.
Require Import MirrorCore.Views.Ptrns.
Require Import MirrorCore.Lambda.ExprCore.
Require Import MirrorCore.Lambda.ExprD.
Require Import MirrorCore.Lambda.RedAll.
Require Import MirrorCore.Lambda.RewriteRelations.
Require Import MirrorCore.Lambda.RewriteStrat.
Require Import MirrorCore.Lambda.Red.
Require Import MirrorCore.Lambda.Ptrns.
Require Import MirrorCore.Lambda.Rewrite.HintDbs.
Require Import MirrorCore.Reify.Reify.
Require Import MirrorCore.RTac.IdtacK.
Require Import MirrorCore.MTypes.ModularTypes.
Require Import MirrorCore.Polymorphic.
Require Import McExamples.PolyRewrite.MSimple.
Require Import McExamples.PolyRewrite.MSimpleReify.

Set Implicit Arguments.
Set Strict Implicit.

Let Rbase := expr typ func.

Existing Instance RType_typ.
Existing Instance Expr.Expr_expr.
Existing Instance Typ2_Fun.
Existing Instance Typ2Ok_Fun.

Definition RbaseD (e : expr typ func) (t : typ)
: option (TypesI.typD t -> TypesI.typD t -> Prop) :=
  env_exprD nil nil (tyArr t (tyArr t tyProp)) e.

Theorem RbaseD_single_type
: forall (r : expr typ func) (t1 t2 : typ)
         (rD1 : TypesI.typD t1 -> TypesI.typD t1 -> Prop)
         (rD2 : TypesI.typD t2 -> TypesI.typD t2 -> Prop),
    RbaseD r t1 = Some rD1 -> RbaseD r t2 = Some rD2 -> t1 = t2.
Proof.
  unfold RbaseD, env_exprD. simpl; intros.
  forward.
  generalize (lambda_exprD_deterministic _ _ _ H0 H). unfold Rty.
  intros. inversion H3. reflexivity.
Qed.

Existing Instance RelDec_eq_mtyp.

Fixpoint from_terms (rs : list (expr typ func))
: refl_dec Rbase :=
  match rs with
  | nil => fun _ => false
  | r :: rs => fun r' =>
    if expr_eq_dec _ _ r r' then true else from_terms rs r'
  end.

Definition is_refl : refl_dec Rbase :=
  fun (r : Rbase) =>
    match r with
    | Inj (Eq _)
    | Inj Impl => true
    | _ => false
    end.

(* TODO(gmalecha): The majority the complexity of this file comes from
 * simplifying the denotation function. A few tactics should improve this
 * dramatically.
 *)
Theorem is_refl_ok : refl_dec_ok RbaseD is_refl.
Proof.
  red.
  destruct r; simpl; try congruence.
  destruct f; simpl; try congruence.
  { unfold RbaseD; simpl.
    unfold env_exprD. simpl. intros.
    autorewrite with exprD_rw in H0.
    forward. inv_all; subst.
    unfold symAs in H0. unfold typeof_sym in H0.
    unfold RSym_func in H0.
    unfold typeof_func in H0.
    forward. inv_all. subst. simpl.
    clear. red in r. inversion r.
    subst.
    rewrite (UIP_refl r). compute. reflexivity. }
  { unfold RbaseD; simpl.
    unfold env_exprD. simpl. intros.
    autorewrite with exprD_rw in H0.
    forward. inv_all; subst.
    unfold symAs in H0. unfold typeof_sym in H0.
    unfold RSym_func in H0.
    unfold typeof_func in H0.
    forward. inv_all. subst. simpl.
    clear. red in r. inversion r.
    subst.
    rewrite (UIP_refl r). compute. intros; tauto. }
Qed.

Definition is_trans : trans_dec Rbase :=
  fun r =>
    match r with
    | Inj (Eq _)
    | Inj Lt
    | Inj Impl => true
    | _ => false
    end.

Theorem is_trans_ok : trans_dec_ok RbaseD is_trans.
Proof.
  red.
  destruct r; simpl; try congruence.
  destruct f; simpl; try congruence.
  { unfold RbaseD; simpl.
    unfold env_exprD. simpl. intros.
    autorewrite with exprD_rw in H0.
    forward. inv_all; subst.
    unfold symAs in H0. unfold typeof_sym in H0.
    unfold RSym_func in H0.
    unfold typeof_func in H0.
    forward. }
  { unfold RbaseD; simpl.
    unfold env_exprD. simpl. intros.
    autorewrite with exprD_rw in H0.
    forward. inv_all; subst.
    unfold symAs in H0. unfold typeof_sym in H0.
    unfold RSym_func in H0.
    unfold typeof_func in H0.
    forward. inv_all. subst.
    simpl. clear. inversion r.
    subst. rewrite (UIP_refl r). compute. congruence. }
  { unfold RbaseD; simpl.
    unfold env_exprD. simpl. intros.
    autorewrite with exprD_rw in H0.
    forward. inv_all; subst.
    unfold symAs in H0. unfold typeof_sym in H0.
    unfold RSym_func in H0.
    unfold typeof_func in H0.
    forward. inv_all. subst.
    clear. inversion r. subst.
    rewrite (UIP_refl r).
    compute. tauto. }
Qed.

(** This is the semantic lemma *)
Theorem pull_ex_and_left
: forall T P Q, Basics.flip Basics.impl ((@ex T P) /\ Q) (exists n, P n /\ Q).
Proof.
  do 2 red. intros.
  destruct H. destruct H. split; eauto.
Qed.

(** Reify it *)
Definition lem_pull_ex_and_left : polymorphic typ 1 (Lemma.lemma typ (expr typ func) (rw_concl typ func Rbase)) :=
  Eval unfold Lemma.add_var, Lemma.add_prem , Lemma.vars , Lemma.concl , Lemma.premises in
  <:: @pull_ex_and_left ::>.

(*
Reify BuildPolyLemma 1 < reify_simple_typ reify_simple reify_concl_base >
  lem_pull_ex_and_left : @pull_ex_and_left.
*)

Ltac get_num_arrs t :=
  lazymatch t with
  | _ -> ?T => let x := get_num_arrs T in
               constr:(S x)
  | _ => constr:(0)
  end.

Ltac reduce_exprT :=
  repeat progress (red; simpl; repeat rewrite mtyp_cast_refl);
  unfold AbsAppI.exprT_App, exprT_Inj, Rcast_val, Rcast, Relim, Rsym; simpl.

Ltac polymorphicD_intro :=
  try lazymatch goal with
    | |- @polymorphicD _ _ _ O _ =>
      red
    | |- @polymorphicD _ _ _ (S _) _ => intro ; polymorphicD_intro
    end.

Ltac prove_lem lem :=
  polymorphicD_intro ;
  red; intros;
  reduce_exprT ;
  try first [ exact lem
            | exact (lem _)
            | exact (lem _ _)
            | exact (lem _ _ _)
            | exact (lem _ _ _ _)
            | exact (lem _ _ _ _ _)
            | exact (lem _ _ _ _ _ _)
            ].

Lemma lem_pull_ex_and_left_sound
: polymorphicD (Lemma.lemmaD (rw_conclD RbaseD) nil nil) (n:=1) lem_pull_ex_and_left.
Proof. prove_lem pull_ex_and_left. Defined.

Theorem pull_ex_and_right
: forall T P Q, Basics.flip Basics.impl (Q /\ (@ex T P)) (exists n, Q /\ P n).
Proof.
  destruct 1. destruct H.
  split; eauto.
Qed.

Definition lem_pull_ex_and_right : polymorphic typ 1 (Lemma.lemma typ (expr typ func) (rw_concl typ func Rbase)) :=
  Eval unfold Lemma.add_var, Lemma.add_prem , Lemma.vars , Lemma.concl , Lemma.premises in
  <:: @pull_ex_and_right ::>.

(*
Reify BuildPolyLemma 1 < reify_simple_typ reify_simple reify_concl_base >
  lem_pull_ex_and_right : @pull_ex_and_right.
*)

Lemma lem_pull_ex_and_right_sound
: polymorphicD (Lemma.lemmaD (rw_conclD RbaseD) nil nil) (n:=1) lem_pull_ex_and_right.
Proof. prove_lem pull_ex_and_right. Defined.

Definition flip_impl : R typ Rbase := Rflip (Rinj (Inj Impl)).

Existing Instance RelDec_eq_mtyp.

Require Import MirrorCore.Util.Forwardy.

(*
   write a convencience wrapper that handles everything for mtyp
   figure out what arguments i want to_respectful/do_prespectful to have
   and then make it have them
 *)

Require Import Coq.Classes.Morphisms.

Lemma Proper_exists T
: Proper (Morphisms.pointwise_relation T (Basics.flip Basics.impl) ==> Basics.flip Basics.impl) (@ex T).
Proof. compute. destruct 2; eauto. Qed.

Lemma Proper_forall (T : Type)
: Proper (Morphisms.pointwise_relation T (Basics.flip Basics.impl) ==> Basics.flip Basics.impl)
         (fun P => forall x, P x).
Proof. compute. eauto. Qed.

Lemma Proper_or_flip_impl
: Proper (Basics.flip Basics.impl ==> Basics.flip Basics.impl ==> Basics.flip Basics.impl) or.
Proof. compute. tauto. Qed.

Lemma Proper_and_flip_impl
: Proper (Basics.flip Basics.impl ==> Basics.flip Basics.impl ==> Basics.flip Basics.impl) and.
Proof. compute. tauto. Qed.

Definition lem_Proper_exists
: polymorphic typ 1 (Lemma.lemma typ (expr typ func) (Proper_concl typ func Rbase)) :=
  Eval unfold Lemma.add_var, Lemma.add_prem , Lemma.vars , Lemma.concl , Lemma.premises in
  <:: @Proper_exists ::>.

Definition lem_Proper_forall
: polymorphic typ 1 (Lemma.lemma typ (expr typ func) (Proper_concl typ func Rbase)) :=
  Eval unfold Lemma.add_var, Lemma.add_prem , Lemma.vars , Lemma.concl , Lemma.premises in
  <:: @Proper_forall ::>.

(*
Reify BuildPolyLemma 1 < reify_simple_typ reify_simple reify_proper_concl >
  lem_Proper_exists : @Proper_exists.

Reify BuildPolyLemma 1 < reify_simple_typ reify_simple reify_proper_concl >
  lem_Proper_forall : @Proper_forall.
*)

Theorem Proper_plus_eq : Proper (eq ==> eq ==> eq) plus.
Proof. red. red. red. firstorder. Qed.

Arguments PPr {_ _ _} n _ : clear implicits.

Require Import MirrorCore.Lambda.PolyInst.

Definition get_respectful_only_all_ex : ResolveProper typ func Rbase :=
  do_prespectful rel_dec tyVar (type_sym_unifier (MTypeUnify.mtype_unify _))
    (PPr (typ:=typ) (func:=func) (Rbase:=Rbase) 1 <:: @Proper_forall ::> ::
     PPr (typ:=typ) (func:=func) (Rbase:=Rbase) 1 <:: @Proper_exists ::> :: nil).

Let tyBNat := tyBase0 tyNat.
Definition get_respectful : ResolveProper typ func Rbase :=
  do_prespectful rel_dec (@tyVar typ') (type_sym_unifier (MTypeUnify.mtype_unify _))
    (PPr (typ:=typ) (func:=func) (Rbase:=Rbase) 1 <:: @Proper_forall ::> ::
     PPr (typ:=typ) (func:=func) (Rbase:=Rbase) 1 <:: @Proper_exists ::> ::
     Pr  (typ:=typ) (func:=func) (Rbase:=Rbase) <:: Proper_and_flip_impl ::> ::
     Pr  (typ:=typ) (func:=func) (Rbase:=Rbase) <:: Proper_or_flip_impl ::> ::
     Pr  (typ:=typ) (func:=func) (Rbase:=Rbase) <:: Proper_plus_eq ::> :: nil).

Lemma RelDec_semidec {T} (rT : T -> T -> Prop)
      (RDT : RelDec rT) (RDOT : RelDec_Correct RDT)
: forall a b : T, a ?[ rT ] b = true -> rT a b.
Proof. intros. consider (a ?[ rT ] b); auto. Qed.

Ltac prove_prespectful :=
  first [ simple eapply Pr_sound
        | simple eapply PPr_sound
        | simple eapply PPr_tc_sound ] ; polymorphicD_intro;
  reduce_exprT.
(*
  repeat match goal with
         | |- context[mtyp_cast _ _ _ _] => rewrite mtyp_cast_refl
         | _ => red; simpl
         end.
*)

Theorem get_respectful_only_all_ex_sound
: respectful_spec RbaseD get_respectful_only_all_ex.
Proof.
  eapply do_prespectful_sound; [eapply rel_dec_correct|].
  red; repeat first [ simple eapply Forall_cons; [ prove_prespectful | ]
                    | simple eapply Forall_nil].
  eapply Proper_forall.
  eapply Proper_exists.
Qed.

Theorem get_respectful_sound : respectful_spec RbaseD get_respectful.
Proof.
  (** TODO: Make respectful_spec opaque to type classes
   **  Hint Opaque respectful_sepc.
   **)
  eapply do_prespectful_sound; [eapply rel_dec_correct|].
  (** Encapsulate this into 'prove_ProperDb' tactic *)
  red; repeat first [ simple apply Forall_cons; [ prove_prespectful | ]
                    | simple apply Forall_nil ].
  all: try refine (@Proper_forall _).
  all: try refine (@Proper_exists _).
  all: try eapply Proper_and_flip_impl.
  all: try eapply Proper_or_flip_impl.
  all: try eapply Proper_plus_eq.
Qed.

Require Import MirrorCore.Views.Ptrns.

Definition simple_reduce (e : expr typ func) : expr typ func :=
  run_ptrn
    (pmap (fun abcd => let '(a,(b,(c,d),e)) := abcd in
                       App a (Abs c (App (App b d) e)))
          (app get (abs get (fun t =>
                               app (app get
                                        (pmap (fun x => (t,Red.beta x)) get))
                                   (pmap Red.beta get)))))
    e e.

(* build hint database from provided lemmas list *)
(*
Definition build_hint_db (lems : list (rw_lemma typ func (expr typ func) *
                                     CoreK.rtacK typ (expr typ func))) : RewriteHintDb Rbase :=
  List.map (fun l => let '(rwl, rtc) := l in
                  Rw rwl rtc
           ) lems.
*)

Definition the_rewrites (lems : RewriteHintDb Rbase)
  : RwAction typ func Rbase :=
  rw_post_simplify simple_reduce (rw_simplify Red.beta (using_prewrite_db rel_dec (CompileHints (type_sym_unifier (MTypeUnify.mtype_unify _)) lems))).

Lemma simple_reduce_sound :
  forall (tus tvs : tenv typ) (t : typ) (e : expr typ func)
         (eD : exprT tus tvs (TypesI.typD t)),
    ExprDsimul.ExprDenote.lambda_exprD tus tvs t e = Some eD ->
    exists eD' : exprT tus tvs (TypesI.typD t),
      ExprDsimul.ExprDenote.lambda_exprD tus tvs t (simple_reduce e) = Some eD' /\
      (forall (us : HList.hlist TypesI.typD tus)
              (vs : HList.hlist TypesI.typD tvs), eD us vs = eD' us vs).
Proof.
  unfold simple_reduce.
  intros.
  revert H.
  eapply Ptrns.run_ptrn_sound.
  { repeat first [ simple eapply ptrn_ok_pmap
                 | simple eapply ptrn_ok_app
                 | simple eapply ptrn_ok_abs; intros
                 | simple eapply ptrn_ok_get
                 ]. }
  { do 3 red. intros; subst.
    reflexivity. }
  { intros. ptrnE.
    eapply lambda_exprD_Abs_prem in H; forward_reason; subst.
    inv_all. subst.
    generalize (Red.beta_sound tus (x4 :: tvs) x10 x6).
    generalize (Red.beta_sound tus (x4 :: tvs) x7 x).
    simpl.
    change_rewrite H1. change_rewrite H2.
    intros; forward.
    erewrite lambda_exprD_App; try eassumption.
    2: erewrite lambda_exprD_Abs; try eauto with typeclass_instances.
    2: rewrite typ2_match_iota; eauto with typeclass_instances.
    2: rewrite type_cast_refl; eauto with typeclass_instances.
    2: erewrite lambda_exprD_App; try eassumption.
    3: erewrite lambda_exprD_App; try eassumption; eauto.
    2: autorewrite_with_eq_rw; reflexivity.
    simpl. eexists; split; eauto.
    unfold AbsAppI.exprT_App, AbsAppI.exprT_Abs. simpl.
    intros. unfold Rrefl, Rcast_val, Rcast, Relim; simpl.
    f_equal.
    apply FunctionalExtensionality.functional_extensionality.
    intros. rewrite H5. rewrite H6. reflexivity. }
  { eauto. }
Qed.

Theorem the_rewrites_sound
: forall hints, RewriteHintDbOk RbaseD hints ->
    setoid_rewrite_spec RbaseD (the_rewrites hints).
Proof.
  unfold the_rewrites. intros.
  eapply rw_post_simplify_sound.
  { eapply simple_reduce_sound. }
  eapply rw_simplify_sound.
  (** This type should be named
     ** It might already be named but it should have a better name.
     ** Probably the code from RTac/Simplify.v or something that is pretty close to it
     ** And then, Red and RedAll should export functions that have this type.
     **)
  { intros.
    generalize (Red.beta_sound tus tvs e t). rewrite H0.
    intros; forward. eauto. }
  eapply using_prewrite_db_sound; eauto with typeclass_instances.
  { eapply RelDec_semidec; eauto with typeclass_instances. }
  { eapply RbaseD_single_type. }
  { eapply CompileHints_sound.
    auto. }
Qed.

Definition the_lemmas
: RewriteHintDb Rbase :=
  @PRw _ _ _ 1 lem_pull_ex_and_left IDTACK ::
  @PRw _ _ _ 1 lem_pull_ex_and_right IDTACK ::
  nil.

Theorem the_lemmas_sound : RewriteHintDbOk RbaseD the_lemmas.
Proof.
  repeat first [ apply Forall_cons | apply Forall_nil ]; split; try apply IDTACK_sound.
  { unfold polymorphicD. intros. apply lem_pull_ex_and_left_sound. }
  { unfold polymorphicD. intros. apply lem_pull_ex_and_right_sound. }
Qed.

Definition pull_all_quant : RwAction typ func Rbase :=
  repeat_rewrite (fun e r =>
                    bottom_up (is_reflR is_refl) (is_transR is_trans) (the_rewrites the_lemmas)
                              get_respectful_only_all_ex e r)
                 (is_reflR is_refl) (is_transR is_trans) false 300.

Theorem pull_all_quant_sound : setoid_rewrite_spec RbaseD pull_all_quant.
Proof.
  eapply repeat_rewrite_sound.
  + eapply bottom_up_sound.
    - eapply RbaseD_single_type.
    - eapply is_reflROk. eapply is_refl_ok.
    - eapply is_transROk. eapply is_trans_ok.
    - eapply the_rewrites_sound. eapply the_lemmas_sound.
    - eapply get_respectful_only_all_ex_sound.
  + eapply is_reflROk. eapply is_refl_ok.
  + eapply is_transROk. eapply is_trans_ok.
Qed.

Definition quant_pull : RwAction _ _ _ :=
  bottom_up (is_reflR is_refl) (is_transR is_trans) pull_all_quant get_respectful.

Theorem quant_pull_sound : setoid_rewrite_spec RbaseD quant_pull.
Proof.
  eapply bottom_up_sound.
  - eapply RbaseD_single_type.
  - eapply is_reflROk. eapply is_refl_ok.
  - eapply is_transROk. eapply is_trans_ok.
  - eapply pull_all_quant_sound.
  - eapply get_respectful_sound.
Qed.

(* use mtyps instead of typs in lambda - lambdaMT *)
