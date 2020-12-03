{-# LANGUAGE LambdaCase #-}

-- |
-- Module      : Jikka.Converter.Core.StrengthReduction
-- Description : replace stronger functions in exprs with weaker functions.
-- Copyright   : (c) Kimiyuki Onaka, 2020
-- License     : Apache License 2.0
-- Maintainer  : kimiyuki95@gmail.com
-- Stability   : experimental
-- Portability : portable
--
-- `Jikka.Language.Core.StrengthReduction` replaces strong functions in exprs with weaker functions.
-- For example, this replace @abs x@ with @max x (- x)@.
module Jikka.Converter.Core.StrengthReduction
  ( run,
  )
where

import Jikka.Language.Core.BuiltinPatterns
import Jikka.Language.Core.Expr
import Jikka.Language.Core.Lint (typecheckProgram')
import Jikka.Language.Core.Vars

go :: Expr -> Expr
go = weakenExpr

-- | `eliminateSomeBuiltins` removes some `Builtin` from `Expr` at all.
eliminateSomeBuiltins :: Expr -> Expr
eliminateSomeBuiltins = \case
  -- arithmetical functions
  Minus' e1 e2 -> go $ Plus' e1 (Negate' e2)
  -- advanced arithmetical functions
  Abs' e -> go $ Max' e (Negate' e)
  Lcm' e1 e2 -> go $ FloorDiv' (Gcd' e1 e2) (Mult' e1 e2)
  -- logical functions
  Implies' e1 e2 -> Or' (Not' e1) e2
  -- arithmetical relations
  GreaterThan' e1 e2 -> LessThan' e2 e1
  GreaterEqual' e1 e2 -> LessEqual' e2 e1
  -- equality relations (polymorphic)
  NotEqual' t e1 e2 -> Not' (Equal' t e1 e2)
  e -> e

-- | `reduceNegate` brings `Negate` to the root.
reduceNegate :: Expr -> Expr
reduceNegate = \case
  Negate' (Negate' e) -> e
  Plus' (Negate' e1) (Negate' e2) -> go $ Negate' (Plus' e1 e2)
  -- `Minus` is already removed.
  Mult' (Negate' e1) e2 -> go $ Negate' (Mult' e1 e2)
  Mult' e1 (Negate' e2) -> go $ Negate' (Mult' e1 e2)
  Mult' e1 (Negate' e2) -> go $ Negate' (Mult' e1 e2)
  -- `Abs` is already removed.
  Min' (Negate' e1) (Negate' e2) -> go $ Negate' (Max' e1 e2)
  Max' (Negate' e1) (Negate' e2) -> go $ Negate' (Min' e1 e2)
  e -> e

-- | `reduceNot` brings `Not` to the root.
reduceNot :: Expr -> Expr
reduceNot = \case
  Not' (Not' e) -> e
  And' (Not' e1) (Not' e2) -> go $ Not' (Or' e1 e2)
  Or' (Not' e1) (Not' e2) -> go $ Not' (And' e1 e2)
  -- `Implies` is already removed.
  Mult' (Negate' e1) e2 -> go $ Negate' (Mult' e1 e2)
  Mult' e1 (Negate' e2) -> go $ Negate' (Mult' e1 e2)
  Mult' e1 (Negate' e2) -> go $ Negate' (Mult' e1 e2)
  If' t (Not' e1) e2 e3 -> go $ If' t e1 e3 e2
  e -> e

-- | `reduceBitNot` brings `BitNot` to the root.
reduceBitNot :: Expr -> Expr
reduceBitNot = \case
  BitNot' (BitNot' e) -> e
  BitAnd' (BitNot' e1) (BitNot' e2) -> go $ BitNot' (BitOr' e1 e2)
  BitOr' (BitNot' e1) (BitNot' e2) -> go $ BitNot' (BitAnd' e1 e2)
  BitXor' (BitNot' e1) e2 -> go $ BitNot' (BitXor' e1 e2)
  BitXor' e1 (BitNot' e2) -> go $ BitNot' (BitXor' e1 e2)
  e -> e

reduceAssoc :: Expr -> Expr
reduceAssoc = \case
  Plus' (Plus' e1 e2) e3 -> Plus' e1 (Plus' e2 e3)
  Minus' (Minus' e1 e2) e3 -> Minus' e1 (Minus' e2 e3)
  Mult' (Mult' e1 e2) e3 -> Mult' e1 (Mult' e2 e3)
  Max' (Max' e1 e2) e3 -> Max' e1 (Max' e2 e3)
  Min' (Min' e1 e2) e3 -> Min' e1 (Min' e2 e3)
  And' (And' e1 e2) e3 -> And' e1 (And' e2 e3)
  Or' (Or' e1 e2) e3 -> Or' e1 (Or' e2 e3)
  BitAnd' (BitAnd' e1 e2) e3 -> BitAnd' e1 (BitAnd' e2 e3)
  BitOr' (BitOr' e1 e2) e3 -> BitOr' e1 (BitOr' e2 e3)
  BitXor' (BitXor' e1 e2) e3 -> BitXor' e1 (BitXor' e2 e3)
  e -> e

-- | `reduceBuild` converts all other list constucting functions to `Range1`.
reduceBuild :: Expr -> Expr
reduceBuild = \case
  Tabulate' t n f -> go $ Map' IntTy t f (Range1' n)
  Range2' l r ->
    let n = Minus' r l
        x = findFreshVar n
     in go $ Tabulate' IntTy (Lam1 x IntTy (Plus' l (Var x))) n
  Range3' l r step ->
    let n = CeilDiv' (Minus' r l) step
        x = findFreshVar n
     in go $ Tabulate' IntTy (Lam1 x IntTy (Plus' l (Mult' step (Var x)))) n
  e -> e

reduceMapMap :: Expr -> Expr
reduceMapMap = \case
  -- reduce `Reversed`
  Reversed' _ (Reversed' _ xs) -> xs
  Reversed' _ (Map' t1 t2 f xs) -> go $ Map' t1 t2 f (Reversed' t1 xs)
  -- reduce `Sorted`
  Sorted' t (Reversed' _ xs) -> Sorted' t xs
  Sorted' t (Sorted' _ xs) -> Sorted' t xs
  Sorted' _ (Range1' n) -> Range1' n
  Sorted' _ (Map' t1 t2 f xs) -> go $ Map' t1 t2 f (Sorted' t1 xs)
  -- reduce `Map`
  Map' _ _ (LamId _ _) xs -> xs
  Map' _ t3 f (Map' t1 _ (Lam1 x t e) xs) -> Map' t1 t3 (Lam1 x t (App f [e])) xs
  Map' _ t3 g (Map' t1 _ f xs) ->
    let x = findFreshVar' [g, f]
     in Map' t1 t3 (Lam1 x t1 (App g [App f [Var x]])) xs
  e -> e

reduceFoldMap :: Expr -> Expr
reduceFoldMap = \case
  -- reduce `Reversed`
  Len' t (Reversed' _ xs) -> go $ Len' t xs
  At' t (Reversed' _ xs) i -> go $ At' t xs (Minus' (Minus' (Len' t xs) i) Lit1)
  Sum' (Reversed' _ xs) -> go $ Sum' xs
  Product' (Reversed' _ xs) -> go $ Product' xs
  Max1' (Reversed' _ xs) -> go $ Max1' xs
  Min1' (Reversed' _ xs) -> go $ Min1' xs
  ArgMin' (Reversed' _ xs) -> go $ ArgMin' xs
  ArgMax' (Reversed' _ xs) -> go $ ArgMax' xs
  All' (Reversed' _ xs) -> go $ All' xs
  Any' (Reversed' _ xs) -> go $ Any' xs
  -- reduce `Sorted`
  Len' t (Sorted' _ xs) -> go $ Len' t xs
  Sum' (Sorted' _ xs) -> go $ Sum' xs
  Product' (Sorted' _ xs) -> go $ Product' xs
  Max1' (Sorted' _ xs) -> go $ Max1' xs
  Min1' (Sorted' _ xs) -> go $ Min1' xs
  All' (Sorted' _ xs) -> go $ All' xs
  Any' (Sorted' _ xs) -> go $ Any' xs
  -- reduce `Map`
  Len' _ (Map' t1 _ _ xs) -> go $ Len' t1 xs
  At' _ (Map' t1 _ f xs) i -> go $ App f [At' t1 xs i]
  Sum' (Map' t1 _ (Lam1 x _ e) xs) | x `isUnusedVar` e -> go $ Mult' (Len' t1 xs) e
  Sum' (Map' t1 t2 (Lam1 x t (Negate' e)) xs) -> go $ Negate' (Sum' (Map' t1 t2 (Lam1 x t e) xs))
  Sum' (Map' t1 t2 (Lam1 x t (Plus' e1 e2)) xs) -> go $ Plus' (Sum' (Map' t1 t2 (Lam1 x t e1) xs)) (Sum' (Map' t1 t2 (Lam1 x t e2) xs))
  Sum' (Map' t1 t2 (Lam1 x t (Mult' e1 e2)) xs) | x `isUnusedVar` e1 -> go $ Mult' e1 (Sum' (Map' t1 t2 (Lam1 x t e2) xs))
  Sum' (Map' t1 t2 (Lam1 x t (Mult' e1 e2)) xs) | x `isUnusedVar` e2 -> go $ Mult' e2 (Sum' (Map' t1 t2 (Lam1 x t e1) xs))
  Product' (Map' t1 _ (Lam1 x _ e) xs) | x `isUnusedVar` e -> go $ Pow' e (Len' t1 xs)
  Product' (Map' t1 t2 (Lam1 x t (Negate' e)) xs) -> go $ Mult' (Pow' (Negate' Lit0) (Len' t1 xs)) (Product' (Map' t1 t2 (Lam1 x t e) xs))
  Product' (Map' t1 t2 (Lam1 x t (Mult' e1 e2)) xs) -> go $ Mult' (Product' (Map' t1 t2 (Lam1 x t e1) xs)) (Product' (Map' t1 t2 (Lam1 x t e2) xs))
  Max1' (Map' _ _ (Lam1 x _ e) _) | x `isUnusedVar` e -> e
  Max1' (Map' t1 t2 (Lam1 x t (Max' e1 e2)) xs) -> go $ Max' (Map' t1 t2 (Lam1 x t e1) xs) (Map' t1 t2 (Lam1 x t e2) xs)
  Max1' (Map' t1 t2 (Lam1 x t (Negate' e)) xs) -> go $ Negate' (Min1' (Map' t1 t2 (Lam1 x t e) xs))
  Max1' (Map' t1 t2 (Lam1 x t (Plus' e1 e2)) xs) | x `isUnusedVar` e1 -> go $ Plus' e1 (Max1' (Map' t1 t2 (Lam1 x t e2) xs))
  Max1' (Map' t1 t2 (Lam1 x t (Plus' e1 e2)) xs) | x `isUnusedVar` e2 -> go $ Plus' (Max1' (Map' t1 t2 (Lam1 x t e1) xs)) e1
  Min1' (Map' _ _ (Lam1 x _ e) _) | x `isUnusedVar` e -> e
  Min1' (Map' t1 t2 (Lam1 x t (Min' e1 e2)) xs) -> go $ Min' (Map' t1 t2 (Lam1 x t e1) xs) (Map' t1 t2 (Lam1 x t e2) xs)
  Min1' (Map' t1 t2 (Lam1 x t (Negate' e)) xs) -> go $ Negate' (Max1' (Map' t1 t2 (Lam1 x t e) xs))
  Min1' (Map' t1 t2 (Lam1 x t (Plus' e1 e2)) xs) | x `isUnusedVar` e1 -> go $ Plus' e1 (Min1' (Map' t1 t2 (Lam1 x t e2) xs))
  Min1' (Map' t1 t2 (Lam1 x t (Plus' e1 e2)) xs) | x `isUnusedVar` e2 -> go $ Plus' (Min1' (Map' t1 t2 (Lam1 x t e1) xs)) e1
  ArgMax' (Map' _ _ (Lam1 x t e) xs) | x `isUnusedVar` e -> go $ Minus' (Len' t xs) Lit1
  ArgMax' (Map' t1 t2 (Lam1 x t (Plus' e1 e2)) xs) | x `isUnusedVar` e1 -> go $ ArgMax' (Map' t1 t2 (Lam1 x t e2) xs)
  ArgMax' (Map' t1 t2 (Lam1 x t (Plus' e1 e2)) xs) | x `isUnusedVar` e2 -> go $ ArgMax' (Map' t1 t2 (Lam1 x t e1) xs)
  ArgMin' (Map' _ _ (Lam1 x _ e) _) | x `isUnusedVar` e -> Lit0
  ArgMin' (Map' t1 t2 (Lam1 x t (Plus' e1 e2)) xs) | x `isUnusedVar` e1 -> go $ ArgMin' (Map' t1 t2 (Lam1 x t e2) xs)
  ArgMin' (Map' t1 t2 (Lam1 x t (Plus' e1 e2)) xs) | x `isUnusedVar` e2 -> go $ ArgMin' (Map' t1 t2 (Lam1 x t e1) xs)
  e -> e

reduceFoldBuild :: Expr -> Expr
reduceFoldBuild = \case
  Len' _ (Range1' n) -> n
  At' _ (Range1' _) i -> i
  Sum' (Range1' n) -> go $ FloorDiv' (Mult' n (Minus' n Lit1)) Lit2
  Sum' (Map' _ _ (Lam1 x _ (Mult' x' x'')) (Range1' n)) | x' == Var x && x'' == Var x -> go $ FloorDiv' (Mult' n (Mult' (Minus' n Lit1) (Minus' (Mult' Lit2 n) Lit1))) (Lit (LitInt 6))
  Sum' (Map' _ _ (Lam1 x _ (Mult' x' (Mult' x'' x'''))) (Range1' n)) | x' == Var x && x'' == Var x && x''' == Var x -> go $ FloorDiv' (Mult' n (Mult' n (Mult' (Minus' n Lit1) (Minus' n Lit1)))) (Lit (LitInt 4))
  Product' (Range1' n) -> go $ If' IntTy (Equal' IntTy n Lit0) Lit1 Lit0
  Max1' (Range1' n) -> go $ Minus' n Lit1
  Min1' (Range1' _) -> Lit0
  ArgMax' (Range1' n) -> go $ Minus' n Lit1
  ArgMin' (Range1' _) -> Lit0
  e -> e

reduceList :: Expr -> Expr
reduceList = reduceFoldBuild . reduceFoldMap . reduceMapMap . reduceBuild

misc :: Expr -> Expr
misc = \case
  -- arithmetical functions
  Pow' (Pow' e1 e2) e3 -> go $ Pow' e1 (Plus' e2 e3)
  -- advanced arithmetical functions
  Gcd' (Mult' k1 e1) (Mult' k2 e2) | k1 == k2 -> go $ Mult' k1 (Gcd' e1 e2)
  Gcd' (Mult' k1 e1) (Mult' e2 k2) | k1 == k2 -> go $ Mult' k1 (Gcd' e1 e2)
  Gcd' (Mult' e1 k1) (Mult' e2 k2) | k1 == k2 -> go $ Mult' k1 (Gcd' e1 e2)
  Gcd' (Mult' e1 k1) (Mult' k2 e2) | k1 == k2 -> go $ Mult' k1 (Gcd' e1 e2)
  e -> e

weakenAppBuiltin' :: Expr -> Expr
weakenAppBuiltin' = misc . reduceList . reduceAssoc . reduceBitNot . reduceNot . reduceNegate . eliminateSomeBuiltins

weakenAppBuiltin :: Builtin -> [Expr] -> Expr
weakenAppBuiltin builtin args = weakenAppBuiltin' (AppBuiltin builtin args)

weakenExpr :: Expr -> Expr
weakenExpr = \case
  Var x -> Var x
  Lit lit -> Lit lit
  App f args -> case (weakenExpr f, map weakenExpr args) of
    (Builtin builtin, args) -> weakenAppBuiltin builtin args
    (f, args) -> App f args
  Lam args e -> Lam args (weakenExpr e)
  Let x t e1 e2 -> Let x t (weakenExpr e1) (weakenExpr e2)

weakenToplevelExpr :: ToplevelExpr -> ToplevelExpr
weakenToplevelExpr e = case e of
  ResultExpr e -> ResultExpr $ weakenExpr e
  ToplevelLet rec x args ret body cont -> ToplevelLet rec x args ret (weakenExpr body) (weakenToplevelExpr cont)

run :: Program -> Either String Program
run = typecheckProgram' . weakenToplevelExpr