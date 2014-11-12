Require Import Coq.Bool.Bool.
Require Import Coq.Lists.List.
Require Import Coq.Classes.Morphisms.
Require Import ExtLib.Core.RelDec.
Require Import ExtLib.Data.HList.
Require Import ExtLib.Tactics.
Require Import MirrorCore.TypesI.
Require Import MirrorCore.ExprI.
Require Import MirrorCore.EnvI.
Require Import MirrorCore.CtxLogic.

Set Implicit Arguments.
Set Strict Implicit.

Section with_Expr.
  Variable typ : Type.
  Variable expr : Type.
  Context {RType_typ : RType typ}.
  Context {RTypeOk_typ : RTypeOk}.
  Context {Expr_expr : @Expr typ _ expr}.

  Class ExprVar : Type :=
  { Var : var -> expr
  ; mentionsV : var -> expr -> bool
  }.

  Class ExprVarOk (EV : ExprVar) : Prop :=
  { Var_exprD'
    : forall tus tvs v t,
        match exprD' tus tvs (Var v) t with
          | None =>
            nth_error tvs v = None \/
            exists t', nth_error tvs v = Some t' /\ ~Rty t t'
          | Some vD =>
            exists get,
            nth_error_get_hlist_nth typD tvs v = Some (@existT _ _ t get) /\
            forall us vs,
              get vs = vD us vs
        end
  ; exprD'_strengthenV_single
    : forall tus tvs e t t' val,
      mentionsV (length tvs) e = false ->
      exprD' tus (tvs ++ t :: nil) e t' = Some val ->
      exists val',
        exprD' tus tvs e t' = Some val' /\
        forall us vs u,
          val us (hlist_app vs (Hcons u Hnil)) = val' us vs
  ; mentionsV_Var : forall v v', mentionsV v (Var v') = true <-> v = v'
  }.

  Lemma exprD'_exact_var {EV} {EVO : ExprVarOk EV} tus tvs tvs' t
  : exists eD' : exprT tus (tvs ++ t :: tvs') (typD t),
      exprD' tus (tvs ++ t :: tvs') (Var (length tvs)) t = Some eD' /\
      (forall (us : hlist typD tus) (vs : hlist typD tvs) vs'
        (x : typD t), eD' us (hlist_app vs (Hcons x vs')) = x).
  Proof.
    generalize (Var_exprD' tus (tvs ++ t :: tvs') (length tvs) t).
    destruct (exprD' tus (tvs ++ t :: tvs') (Var (length tvs)) t).
    { destruct 1 as [ ? [ ? ? ] ]. eexists; split; eauto.
      intros. rewrite <- H0; clear H0. clear - H RTypeOk_typ.
      eapply nth_error_get_hlist_nth_appR in H; eauto.
      simpl in H. destruct H as [ ? [ ? ? ] ].
      rewrite Minus.minus_diag in H.
      inv_all.
      rewrite H0. subst. reflexivity. }
    { intros. exfalso.
      rewrite ListNth.nth_error_app_R in H by omega.
      cutrewrite (length tvs - length tvs = 0) in H; [ | omega ].
      simpl in *. unfold value in *.
      destruct H; try congruence.
      destruct H. destruct H.
      inversion H. apply H0. assumption. }
  Qed.

  Class ExprUVar : Type :=
  { UVar : uvar -> expr
  ; mentionsU : uvar -> expr -> bool
  ; instantiate : (uvar -> option expr) -> nat -> expr -> expr
  }.


  Definition sem_preserves_if_ho tus tvs
             (P : exprT tus tvs Prop -> Prop)
             (f : uvar -> option expr) : Prop :=
    forall u e t get,
      f u = Some e ->
      nth_error_get_hlist_nth _ tus u = Some (@existT _ _ t get) ->
      exists eD,
        exprD' tus tvs e t = Some eD /\
        P (fun us vs => get us = eD us vs).

  Definition sem_preserves_if tus tvs
             (P : exprT tus tvs Prop)
             (f : uvar -> option expr) : Prop :=
    @sem_preserves_if_ho tus tvs
                         (fun P' => forall us vs, P us vs -> P' us vs) f.

  Definition instantiate_spec_ho
             (instantiate : (uvar -> option expr) -> nat -> expr -> expr)
  : Prop :=
    forall tus tvs f e tvs' t eD P (EApp : CtxLogic.ExprTApplicative P),
      sem_preserves_if_ho P f ->
      exprD' tus (tvs' ++ tvs) e t = Some eD ->
      exists eD',
        exprD' tus (tvs' ++ tvs) (instantiate f (length tvs') e) t = Some eD' /\
        P (fun us vs => forall vs',
                          eD us (hlist_app vs' vs) = eD' us (hlist_app vs' vs)).

  Definition instantiate_spec
             (instantiate : (uvar -> option expr) -> nat -> expr -> expr)
  : Prop :=
    forall tus tvs f e tvs' t eD P,
      @sem_preserves_if tus tvs P f ->
      exprD' tus (tvs' ++ tvs) e t = Some eD ->
      exists eD',
        exprD' tus (tvs' ++ tvs) (instantiate f (length tvs') e) t = Some eD' /\
        forall us vs vs', P us vs ->
          eD us (hlist_app vs' vs) = eD' us (hlist_app vs' vs).

  Definition instantiate_mentionsU_spec
             (instantiate : (uvar -> option expr) -> nat -> expr -> expr)
             (mentionsU : uvar -> expr -> bool)
  : Prop :=
    forall f n e u,
      mentionsU u (instantiate f n e) = true <-> (** do i need iff? **)
      (   (f u = None /\ mentionsU u e = true)
       \/ exists u' e',
            f u' = Some e' /\
            mentionsU u' e = true /\
            mentionsU u e' = true).

  Class ExprUVarOk (EU : ExprUVar) : Prop :=
  { UVar_exprD'
    : forall tus tvs v t,
        match exprD' tus tvs (UVar v) t with
          | None =>
            nth_error tus v = None \/
            exists t', nth_error tus v = Some t' /\ ~Rty t t'
          | Some vD =>
            exists get,
            nth_error_get_hlist_nth typD tus v = Some (@existT _ _ t get) /\
            forall us vs,
              get us = vD us vs
        end
  ; exprD'_strengthenU_single
    : forall tus tvs e t t' val,
      mentionsU (length tus) e = false ->
      exprD' (tus ++ t :: nil) tvs e t' = Some val ->
      exists val',
        exprD' tus tvs e t' = Some val' /\
        forall us vs u,
          val (hlist_app us (Hcons u Hnil)) vs = val' us vs
  ; mentionsU_UVar : forall v v', mentionsU v (UVar v') = true <-> v = v'
  ; instantiate_mentionsU : instantiate_mentionsU_spec instantiate mentionsU
  ; instantiate_sound_ho : instantiate_spec_ho instantiate
  }.

  Theorem instantiate_sound (EU : ExprUVar) (EUO : ExprUVarOk EU)
  : instantiate_spec instantiate.
  Proof.
    red; intros.
    eapply (@instantiate_sound_ho _ EUO) in H0; try eassumption.
    - forward_reason; eauto.
    - eapply (ExprTApplicative_foralls_impl).
  Qed.

  Lemma exprD'_exact_uvar {EU} {EUO : ExprUVarOk EU} tus tus' tvs t
  : exists eD' : exprT (tus ++ t :: tus') tvs (typD t),
      exprD' (tus ++ t :: tus') tvs (UVar (length tus)) t = Some eD' /\
      (forall (us : hlist typD tus) us' (vs : hlist typD tvs)
        (x : typD t), eD' (hlist_app us (Hcons x us')) vs = x).
  Proof.
    generalize (UVar_exprD' (tus ++ t :: tus') tvs (length tus) t).
    destruct (exprD' (tus ++ t :: tus') tvs (UVar (length tus)) t).
    { destruct 1 as [ ? [ ? ? ] ]. eexists; split; eauto.
      intros. rewrite <- H0; clear H0. clear - H RTypeOk_typ.
      eapply nth_error_get_hlist_nth_appR in H; eauto.
      simpl in H. destruct H as [ ? [ ? ? ] ].
      rewrite Minus.minus_diag in H.
      inv_all.
      rewrite H0. subst. reflexivity. }
    { intros. exfalso.
      rewrite ListNth.nth_error_app_R in H by omega.
      rewrite Minus.minus_diag in H.
      simpl in *. unfold value in *.
      destruct H; try congruence.
      destruct H. destruct H.
      inversion H. apply H0. assumption. }
  Qed.

  Class MentionsAny : Type :=
  { mentionsAny : (uvar -> bool) -> (var -> bool) -> expr -> bool }.

  Class MentionsAnyOk (MA : MentionsAny) (MV : ExprVar) (MU : ExprUVar) : Type :=
  { Proper_mentionsAny
    : Proper ((eq ==> eq) ==> (eq ==> eq) ==> eq ==> eq) mentionsAny
  ; mentionsAny_factor
    : forall fu fu' fv fv' e,
          mentionsAny (fun u => fu u || fu' u) (fun v => fv v || fv' v) e
        = mentionsAny fu fv e || mentionsAny fu' fv' e
  ; mentionsAny_mentionsU
    : forall u e, mentionsU u e = mentionsAny (fun u' => u ?[ eq ] u') (fun _ => false) e
  }.

End with_Expr.

Arguments ExprVar expr : rename.
Arguments ExprUVar expr : rename.
Arguments ExprVarOk {typ _ expr _} _ : rename.
Arguments ExprUVarOk {typ _ expr _} _ : rename.
Arguments instantiate {expr ExprUVar} _ _ _ : rename.
Arguments mentionsU {expr ExprUVar} _ _ : rename.
Arguments mentionsV {expr ExprVar} _ _ : rename.
Arguments mentionsAny {expr MentionsAny} _ _ _ : rename.
Arguments instantiate_sound {typ expr RType Expr EU EUO} _ _ _ _ tvs' _ _ P _ _ : rename.
Arguments instantiate_sound_ho {typ expr RType Expr EU EUO} _ _ _ _ tvs' _ _ P _ _ _ : rename.
Arguments instantiate_mentionsU {typ expr RType Expr EU EUO} _ _ _ _ : rename.