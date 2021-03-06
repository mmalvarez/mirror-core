Require Import McExamples.PolyRewrite.Monads.Monad.
Require Import McExamples.PolyRewrite.Monads.RtacDemo.

Declare Module M : Monad.
Declare Module F : Frob M.

Module Automation := RtacDemo.DemoRtacMonad M F.

Goal Automation.Demo.goal NNN.
  Automation.Demo.prep.
  Time Automation.Demo.run.
  Automation.Demo.cleanup.
Time Qed.
