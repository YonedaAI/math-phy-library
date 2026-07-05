-- |
-- Module      : Main
-- Description : Runnable demonstration of the key results of Part II,
--               "Motives, Periods, and Amplitudes: The Coalgebraic Anatomy
--               of Physical Representation".
--
-- Demonstrates:
--   (1) Coassociativity of the coaction (coalgebra axiom).
--   (2) Weight-one words are exactly the primitives; weight >= 2 are not
--       (Generation theorem, part (b)).
--   (3) Anatomy depth of a weight-n object is n-1 (Termination proposition).
--   (4) The dilogarithm symbol and cobracket log(1-x) /\ log(x)
--       (Dilogarithm example).
--   (5) The discontinuity Disc_x Li_2(x) picks out log(1-x)
--       (Discontinuity proposition).
--   (6) Multiplicativity and additivity of the period pairing
--       (Multiplicativity theorem).
--   (7) The coaction transports through a realization channel
--       (Conditional Amplitude Decomposition theorem).
module Main (main) where

import Coalgebra
import Period
import Amplitude
import Goncharov
import Proofs (runAllProofs)
import System.Exit (exitFailure)

-- A generic weight-graded alphabet for the structural demonstrations.
newtype Gen = Gen Char deriving (Eq, Ord)
instance Show Gen where show (Gen c) = [c]

wordOf :: String -> Word' Gen
wordOf = Word' . map Gen

section :: String -> IO ()
section s = do
  putStrLn ""
  putStrLn ("=== " ++ s ++ " ===")

-- | Print a labelled check and return its boolean outcome so the caller can
-- fold every demo check into the process exit status.
check :: String -> Bool -> IO Bool
check name ok = do
  putStrLn ("  [" ++ (if ok then "PASS" else "FAIL") ++ "] " ++ name)
  pure ok

main :: IO ()
main = do
  putStrLn "Motives, Periods, and Amplitudes -- coalgebraic anatomy demo"
  putStrLn "The YonedaAI Collaboration"

  -- (1) Coassociativity of the deconcatenation coaction.
  section "1. Coassociativity of the coaction (coalgebra axiom)"
  let ws = [ wordOf "a", wordOf "ab", wordOf "abc", wordOf "abcd" ]
  r1 <- mapM (\w -> check ("coassoc " ++ show w) (coassocHolds w)) ws

  -- (2) Weight-one primitives; higher weight not primitive.
  section "2. Primitivity by weight (Generation theorem, part b)"
  r2a <- check "weight-1 word 'a' is primitive"      (isPrimitive (wordOf "a"))
  r2b <- check "weight-2 word 'ab' is NOT primitive"  (not (isPrimitive (wordOf "ab")))
  r2c <- check "weight-3 word 'abc' is NOT primitive" (not (isPrimitive (wordOf "abc")))
  putStrLn "  weight-one primitives of {x, 1-x}:"
  mapM_ (\w -> putStrLn ("    " ++ show w ++ "  primitive=" ++ show (isPrimitive w)))
        weightOnePrimitives

  -- (3) Anatomy depth = weight - 1 (Termination proposition).
  section "3. Anatomy depth = weight - 1 (Termination proposition)"
  r3 <- mapM (\w -> do
            let n = weight w
                d = anatomyDepth w
            check ("depth(" ++ show w ++ ") = " ++ show d
                    ++ " = weight-1 = " ++ show (n - 1))
                  (d == n - 1))
        ws

  -- (4) Dilogarithm symbol and cobracket.
  section "4. Dilogarithm symbol and cobracket (Dilog example)"
  putStrLn ("  symbol S(Li_2(x)) word = -" ++ show dilogSymbol
             ++ "   [i.e. -(1-x) (x) x]")
  putStrLn "  cobracket delta Li_2^m(x) = log(1-x) /\\ log(x):"
  mapM_ (\(a, b, c) ->
            putStrLn ("    " ++ show a ++ " (x) " ++ show b
                       ++ "  coeff " ++ show c))
        dilogCobracket

  -- (5) Discontinuity picks out the first coaction slot.
  section "5. Discontinuity Disc_x Li_2(x) (Discontinuity proposition)"
  let discs = discAcross X dilogSymbol
  putStrLn ("  Disc_x picks first-slot factors with second slot = x: "
             ++ show discs)
  r5 <- check "Disc_x Li_2(x) yields log(1-x)"
              (discs == [Word' [OneMinusX]])

  -- (6) Multiplicativity and additivity of the period pairing.
  section "6. Period pairing multiplicativity (Multiplicativity theorem)"
  -- Use the validated Kummer constructor; log 2 and log 3 are in domain.
  case (mkKummerLog 2, mkKummerLog 3) of
    (Just p2, Just p3) -> do
      putStrLn ("  per(Pi_log2) = " ++ show (per p2))
      putStrLn ("  per(Pi_log3) = " ++ show (per p3))
      putStrLn ("  per(Pi_log2 (x) Pi_log3) = " ++ show (per (tensorDatum p2 p3)))
      putStrLn ("  per(log2) * per(log3)    = " ++ show (per p2 * per p3))
      r6a <- check "per(Pi1 (x) Pi2) = per(Pi1) * per(Pi2)" (checkMultiplicative p2 p3)
      r6b <- check "per(Pi1 (+) Pi2) = per(Pi1) + per(Pi2)" (checkAdditive p2 p3)

      -- (7) Coaction transports through a realization channel.
      section "7. Coaction transports through realization (CAD theorem)"
      -- Realization channel: relabel letters a..d -> A..D (a monoidal functor).
      let realizeGen (Gen c) = Gen (toUpperAscii c)
      r7 <- mapM (\w -> check ("Delta'(Real " ++ show w ++ ") = (Real (x) Real) Delta'")
                              (coactionTransports realizeGen w))
                 ws

      -- (8) Equational-reasoning proof checks (executable proofs).
      section "8. Equational reasoning proof checks (Proofs.hs)"
      proofsOk <- runAllProofs

      section "Summary"
      putStrLn "  All model-level checks correspond to theorems in the paper:"
      putStrLn "    coassoc -> coalgebra axiom"
      putStrLn "    primitivity/depth -> Generation + Termination"
      putStrLn "    dilog cobracket -> Goncharov Lie coalgebra"
      putStrLn "    discontinuity -> first coaction slot"
      putStrLn "    period multiplicativity -> Multiplicativity theorem"
      putStrLn "    coaction transport -> Conditional Amplitude Decomposition"

      let demoOk = and (r1 ++ [r2a, r2b, r2c] ++ r3 ++ [r5, r6a, r6b] ++ r7)
      if demoOk && proofsOk
        then putStrLn "\nAll demo and equational proof checks PASSED."
        else do
          putStrLn "\nSome demo or equational proof checks FAILED."
          exitFailure
    _ -> do
      putStrLn "  [FAIL] mkKummerLog rejected an in-domain input"
      exitFailure

-- | ASCII lowercase-to-uppercase without importing Data.Char, to keep the
-- dependency footprint minimal.
toUpperAscii :: Char -> Char
toUpperAscii c
  | c >= 'a' && c <= 'z' = toEnum (fromEnum c - 32)
  | otherwise            = c
