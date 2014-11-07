Require Import ExtLib.Data.Sum.
Require Import ExtLib.Data.HList.
Require Import ExtLib.Tactics.
Require Import MirrorCore.SymI.
Require Import MirrorCore.ExprI.
Require Import MirrorCore.SubstI.
Require Import MirrorCore.ExprDAs.
Require Import MirrorCore.RTac.Core.
Require Import MirrorCore.RTac.RunOnGoals.

Require Import MirrorCore.Util.Forwardy.

Set Implicit Arguments.
Set Strict Implicit.

Section parameterized.
  Variable typ : Type.
  Variable expr : Type.

  Section findHyp.
    Variable T : Type.
    Variable check : expr -> option T.

    Fixpoint findHyp (ctx : Ctx typ expr) {struct ctx}
    : option T :=
      match ctx with
        | CTop _ _ => None
        | CAll ctx' _ => @findHyp ctx'
        | CExs ctx' _ => @findHyp ctx'
        | CHyp ctx' h' =>
          match check h' with
            | None => @findHyp ctx'
            | Some s'' => Some s''
          end
      end.
  End findHyp.

  Context {RType_typ : RType typ}.
  Context {Expr_expr : Expr RType_typ expr}.
  Context {Typ0_Prop : Typ0 _ Prop}.

  Variable check : forall {subst : Type} {S : Subst subst expr},
                     Ctx typ expr -> expr -> expr -> subst -> option subst.

  Definition ASSUMPTION : rtac typ expr :=
    fun _ _ _ _ ctx s gl =>
      match @findHyp (ctx_subst ctx) (fun e => @check _ _ ctx gl e s) ctx with
        | None => Fail
        | Some s' => Solved s'
      end.

(*
  Hypothesis checkOk
  : forall ctx e1 e2 s s',
      check ctx e1 e2 s = Some s' ->
      WellFormed_subst s ->
      let tus := getUVars ctx nil in
      let tvs := getVars ctx nil in
      WellFormed_subst s' /\
      forall v1 v2 sD,
        exprD' tus tvs e1 (@typ0 _ _ Prop _) = Some v1 ->
        exprD' tus tvs e1 (@typ0 _ _ Prop _) = Some v2 ->
        substD tus tvs s = Some sD ->
        exists sD',
             substD tus tvs s' = Some sD'
          /\ forall us vs,
               sD' us vs ->
               sD us vs /\
               v1 us vs = v2 us vs.

  Lemma findHypOk
  : forall ctx tus tvs g s s',
      findHyp (check ctx (** TODO: This isn't right **) g) ctx s = Some s' ->
      WellFormed_subst s ->
      WellFormed_subst s' /\
      let tus' := tus ++ getUVars ctx nil in
      let tvs' := tvs ++ getVars ctx nil in
      match propD  tus' tvs' g
          , substD tus' tvs' s
          , substD tus' tvs' s'
      with
        | Some gD , Some sD , Some sD' =>
          ctxD' ctx (fun (us : hlist _ (rev tus')) (vs : hlist _ (rev tvs')) =>
                       let us := hlist_unrev us in
                       let vs := hlist_unrev vs in
                       sD' us vs ->
                       sD us vs /\ gD us vs)
        | None , _ , _
        | _ , None , _ => True
        | Some _ , Some _ , None => False
      end.
(*
  Proof.
    induction ctx; simpl; intros; try congruence.
    { specialize (IHctx tus (tvs ++ t :: nil) _ _ _ H H0).
      forward_reason; split; eauto.
      forward.
      subst.
      eapply substD_weakenV with (tvs' := t :: nil) in H4.
      eapply exprD'_typ0_weakenV with (tvs' := t :: nil) in H3.
      forward_reason.
      rewrite H4 in H2.
      change_rewrite H3 in H2.
      forwardy.
      rewrite
 }
    { specialize (IHctx (tus ++ t :: nil) tvs _ _ _ H H0).
      forward_reason; split; eauto.
      forward.
      subst. eapply H4. }
    { consider (check ctx g e s); intros.
      { clear IHctx. inv_all; subst.
        eapply checkOk in H; clear checkOk; eauto.
        forward_reason; split; eauto.
        forward.
        destruct o0; inv_all; subst.
*)
  Admitted.
*)

  Theorem ASSUMPTION_sound : rtac_sound ASSUMPTION.
  Proof.
    unfold ASSUMPTION, rtac_sound.
    intros. subst.
  Admitted.

End parameterized.
