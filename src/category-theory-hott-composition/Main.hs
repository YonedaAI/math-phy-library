-- |
-- Module      : Main
-- Description : Runnable demonstration of Part V (Category Theory and HoTT:
--               Composition and Identity) of the Math->Physics Representation
--               Library.
--
-- @main@ exercises the paper's key results:
--   * the composition/identity laws of a category (Section 3);
--   * functoriality and the naturality square (Definitions 3.2, 3.5);
--   * the structural no-cloning obstruction (Theorem T3, Section 6.3);
--   * the groupoid-quotient vs set-quotient refinement (Theorem T4, 6.4).
module Main (main) where

import Control.Monad (unless)
import System.Exit (exitFailure)

import RepCat
  ( Fn(..), compose
  , leftUnitHolds, rightUnitHolds, assocHolds
  , functorPreservesComposition
  , naturalitySquareHolds
  )
import Dagger
  ( tensorDim, biproductDim, cloningObstruction, noUniformCloning
  , snakeStraightens )
import Quotient
  ( orbit, stabilizer, setQuotient, groupoidAutomorphisms
  , retainsGaugeInfo, z2TrivialOnPoint )
import Proofs (runAllProofs)
import Properties (runAllProperties)

-- | Small assertion helper: print a labelled PASS/FAIL line and return the
-- Boolean so the caller can fold every demo check into the final exit status.
check :: String -> Bool -> IO Bool
check label ok = do
  putStrLn ("  [" ++ (if ok then "PASS" else "FAIL") ++ "] " ++ label)
  pure ok

section :: String -> IO ()
section s = putStrLn ("\n== " ++ s ++ " ==")

main :: IO ()
main = do
  putStrLn "Part V: Category Theory and HoTT -- Composition and Identity"
  putStrLn "Runnable demonstration of Theorems T1-T4 (structural facts)."

  section "Section 3: composition and identity laws"
  let f  = Fn (\x -> x + (1 :: Int))     -- morphism  A -> B
      g  = Fn (\x -> x * 2)              -- morphism  B -> C
      h  = Fn (\x -> x - 3)              -- morphism  C -> D
      xs = [-5 .. 5] :: [Int]
  d1 <- check "left  unit  identity . f == f"        (leftUnitHolds f xs)
  d2 <- check "right unit  f . identity == f"        (rightUnitHolds f xs)
  d3 <- check "associativity  h.(g.f) == (h.g).f"    (assocHolds h g f xs)
  putStrLn ("  sample: (g . f)(4) = "
            ++ show (runFn (compose g f) (4 :: Int))
            ++ "  (expected 10)")

  section "Definitions 3.2 & 3.5: functoriality and naturality"
  d4 <- check "functor preserves composition (Maybe)"
          (functorPreservesComposition (* (2 :: Int)) (+ 1)
             [Nothing, Just 0, Just 7])
  d5 <- check "naturality square for safeHead : [] => Maybe"
          (naturalitySquareHolds (show :: Int -> String)
             [[], [1], [1,2,3], [9,8]])

  section "Theorem T3: structural no-cloning (dimension obstruction)"
  putStrLn ("  tensorDim 2 2 = " ++ show (tensorDim 2 2)
            ++ ",  biproductDim 2 2 = " ++ show (biproductDim 2 2)
            ++ "  (accidental coincidence)")
  putStrLn ("  tensorDim 3 3 = " ++ show (tensorDim 3 3)
            ++ ",  biproductDim 3 3 = " ++ show (biproductDim 3 3)
            ++ "  (tensor /= product)")
  d6 <- check "cloning obstructed at (3,3)"     (cloningObstruction 3 3)
  d7 <- check "no uniform cloning in FdHilb"    noUniformCloning
  d8 <- check "snake equation straightens wire" (snakeStraightens 4)

  section "Theorem T4: groupoid quotient finer than set quotient"
  let ga = z2TrivialOnPoint
  putStrLn ("  orbit of () under Z/2 (trivial) : "
            ++ show (orbit ga ()))
  putStrLn ("  set quotient X/G                : "
            ++ show (setQuotient ga [()]))
  putStrLn ("  |Stab_G(())| retained by X//G   : "
            ++ show (groupoidAutomorphisms ga ()))
  putStrLn ("  |Stab| kept by X/G (0-trunc)    : 1")
  d9  <- check "X//G retains a nontrivial stabilizer loop"
           (retainsGaugeInfo ga ())
  d10 <- check "stabilizer of () is all of Z/2"
           (length (stabilizer ga ()) == 2)
  let demoOk = and [d1, d2, d3, d4, d5, d6, d7, d8, d9, d10]

  section "Equational reasoning proof checks (Proofs.hs)"
  proofsOk <- runAllProofs

  section "QuickCheck property suite (Properties.hs)"
  propsOk <- runAllProperties

  putStrLn "\nAll structural demonstrations complete."
  unless (demoOk && proofsOk && propsOk) $ do
    putStrLn "FAILURE: some demo checks, proof checks, or QuickCheck properties failed."
    exitFailure
