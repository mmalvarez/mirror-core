Require Import ExtLib.Structures.Monad.
Require Import MirrorCore.Lambda.ExprD.
Require Import MirrorCore.Examples.Monad2.MonadExpr.
Require Import MirrorCore.Examples.Monad2.MonadReduce.

Add ML Path "../src".
Add ML Path "../../src".
Declare ML Module "reify_Monad2_MonadExpr_plugin".

Ltac reify_left m :=
  let Monad_m := constr:(_ : Monad m) in
  match goal with
    | |- ?L = ?X =>
      let K ts fs us e :=
          let t := constr:(tyM (tyType 1)) in
          let result := constr:(reduce t e) in
          let result' := eval vm_compute in result in
          generalize (@reduceOk m Monad_m ts fs e us nil t result'
                            (@eq_refl _ _)) ;
          let H := fresh in
          intro H ;
          cbv beta iota zeta delta [ ts fs us exprD EnvI.split_env ExprDenote.exprD' ExprDenote.func_simul ExprDenote.Open_App ExprDenote.Open_Inj eq_sym TypesI2.typ2_cast Typ2_tyArr SymEnv.funcD FMapPositive.PositiveMap.find SymEnv.fdenote  SymI.typeof_sym RSym_mext SymI.RSym_sum MonadSym.RSym_mfunc MonadSym.typeof_mfunc TypesI2.type_weaken RType_typ SymI.symD MonadSym.mfuncD TypesI2.typ2_match ExprDenote.funcAs SymEnv.RSym_func SymEnv.func_typeof_sym ExprDenote.Open_GetVAs ExprDenote.Open_GetUAs SymEnv.ftype TypesI2.type_cast ExprDenote.Rcast type_cast TypesI2.Relim TypesI2.Rsym OptionMonad.Monad_option EnvI.nth_error_get_hlist_nth Functor.fmap positive_eq_odec f_equal Option.Functor_option TypesI2.typ2 Relim getType typD ExprDenote.Rcast_val HList.hlist_hd HList.hlist_tl ] in H ;
          simpl in H ;
          clear ts fs us
      in
      reify_expr m K [ L ]
  end.

Ltac reduce_monads m :=
  let Monad_m := constr:(_ : Monad m) in
  match goal with
    | |- ?L = ?R =>
      let K ts fs us el er :=
          let t := constr:(tyM (tyType 1)) in
          change (@MonadReduce.Conclusion_reduce_eq m Monad_m ts fs us nil t el er) ;
          let result := constr:((reduce t el, reduce t er)) in
          let result' := eval vm_compute in result in
          pose (result'V := result') ;
          cut (@MonadReduce.Premise_reduce_eq m Monad_m ts fs us nil t result'V) ;
          [ refine (@reduce_eq m Monad_m ts fs el er us nil t result'V
                               (@eq_refl _ result'V <: result = result'V))
          | cbv beta iota zeta delta [ ts fs us result'V exprD EnvI.split_env ExprDenote.exprD' ExprDenote.func_simul ExprDenote.Open_App ExprDenote.Open_Inj eq_sym TypesI2.typ2_cast Typ2_tyArr SymEnv.funcD FMapPositive.PositiveMap.find SymEnv.fdenote  SymI.typeof_sym RSym_mext SymI.RSym_sum MonadSym.RSym_mfunc MonadSym.typeof_mfunc TypesI2.type_weaken RType_typ SymI.symD MonadSym.mfuncD TypesI2.typ2_match ExprDenote.funcAs SymEnv.RSym_func SymEnv.func_typeof_sym ExprDenote.Open_GetVAs ExprDenote.Open_GetUAs SymEnv.ftype TypesI2.type_cast ExprDenote.Rcast type_cast TypesI2.Relim TypesI2.Rsym OptionMonad.Monad_option EnvI.nth_error_get_hlist_nth Functor.fmap positive_eq_odec f_equal Option.Functor_option TypesI2.typ2 Relim getType typD ExprDenote.Rcast_val HList.hlist_hd HList.hlist_tl MonadReduce.Premise_reduce_eq fst snd ] ;
          simpl ;
          clear ts fs us result'V ]
      in
      reify_expr m K [ L R ]
  end.
