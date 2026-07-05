-- |
-- Module      : Main
-- Description : Runnable demonstrations for Part IV, "Algebraic Topology:
--               Conserved Global Information".
--
-- This driver exercises the companion formalization described in the paper's
-- Section "Companion formalization: Haskell and Lean".  It:
--
--   1. verifies the fundamental relation @d^2 = 0@ (Lemma "Boundaries are
--      cycles") for the circle, torus and 2-sphere, and prints their Betti
--      numbers and Euler characteristics (Definition "Conserved global
--      information functor");
--
--   2. checks the commutative-Frobenius-algebra laws underlying a 2d TQFT
--      (Example "A 2d TQFT is a commutative Frobenius algebra") and prints
--      genus-g partition functions;
--
--   3. computes untwisted Dijkgraaf-Witten partition functions
--      @Z_0(T^2), Z_0(T^3)@ for Z/N and S_3 (Theorem "DW instantiates
--      Locality/descent", Example "G = Z/N, untwisted"), recovering
--      @Z_0(T^3) = N^2@ for the abelian case;
--
--   4. exhibits the Atiyah-Singer / Riemann-Roch index theorem as a realization
--      identity @observable = Real(abstract structure)@ (Theorem
--      "Atiyah-Singer as observable = Real(abstract structure)").
module Main (main) where

import Control.Monad (unless)
import System.Exit (exitFailure)
import Text.Printf (printf)

import ChainComplex
import TQFT
import CharacteristicClass
import Proofs (allProofs)

-- ---------------------------------------------------------------------------

banner :: String -> IO ()
banner s = do
  putStrLn ""
  putStrLn (replicate 72 '=')
  putStrLn s
  putStrLn (replicate 72 '=')

checkMark :: Bool -> String
checkMark True  = "OK"
checkMark False = "FAIL"

-- ---------------------------------------------------------------------------
-- 1. (Co)homology: d^2 = 0, Betti numbers, Euler characteristic
-- ---------------------------------------------------------------------------

demoHomology :: IO ()
demoHomology = do
  banner "1. (Co)homology as conserved global information"
  let spaces =
        [ ("S^1  (circle)", circle,  [1,1])
        , ("T^2  (torus) ", torus,   [1,2,1])
        , ("S^2  (sphere)", sphere2, [1,0,1])
        , ("pt   (point) ", pointSpace, [1])
        ]
  mapM_ report spaces
  where
    report :: (String, ChainComplex, [Int]) -> IO ()
    report (name, cc, expected) = do
      let d2   = dSquaredIsZero cc
          bs   = bettiNumbers cc
          chi  = eulerCharacteristic cc
      printf "  %s : d^2=0 ? %-4s  Betti = %-11s (expected %-9s) chi = %2d\n"
             name (checkMark d2) (show bs) (show expected) chi
      if bs == expected
        then putStrLn "      -> conserved global information matches theory"
        else putStrLn "      -> MISMATCH"

-- ---------------------------------------------------------------------------
-- 2. 2d TQFT = commutative Frobenius algebra
-- ---------------------------------------------------------------------------

demoTQFT :: IO ()
demoTQFT = do
  banner "2. 2d TQFT as a commutative Frobenius algebra (gluing laws)"
  mapM_ report [2, 3, 4]
  where
    report :: Int -> IO ()
    report n = do
      let fa   = groupAlgebraZn n
          laws = frobeniusLawsHold fa
          zs   = [ (g, partitionSurface fa g) | g <- [0, 1, 2] ]
      printf "  k[Z/%d] : Frobenius laws (assoc, comm, unit) ? %s\n" n (checkMark laws)
      mapM_ (\(g, z) ->
               printf "      Z(genus %d surface) = %.1f\n" (g :: Int) (z :: Double)) zs

-- ---------------------------------------------------------------------------
-- 3. Untwisted Dijkgraaf-Witten state sums
-- ---------------------------------------------------------------------------

demoDW :: IO ()
demoDW = do
  banner "3. Untwisted Dijkgraaf-Witten partition functions Z_0(T^2), Z_0(T^3)"
  let ns = [2, 3, 4]
  putStrLn "  Cyclic groups Z/N (abelian => Z_0(T^3) = N^2):"
  mapM_ reportZn ns
  putStrLn "  Nonabelian group S_3 (|G| = 6):"
  let g   = symmetric3
      z2  = dwUntwistedT2 g
      z3  = dwUntwistedT3 g
  printf "      S_3 : Z_0(T^2) = %.3f , Z_0(T^3) = %.3f\n" z2 z3
  where
    reportZn :: Int -> IO ()
    reportZn n = do
      let g   = zmod n
          z2  = dwUntwistedT2 g
          z3  = dwUntwistedT3 g
          ok  = abs (z3 - fromIntegral (n * n)) < 1e-9
      printf "      Z/%d : Z_0(T^2) = %5.1f , Z_0(T^3) = %5.1f  (N^2 = %d ? %s)\n"
             n z2 z3 (n * n) (checkMark ok)

-- ---------------------------------------------------------------------------
-- 4. Index theorem as a realization identity
-- ---------------------------------------------------------------------------

demoIndex :: IO ()
demoIndex = do
  banner "4. Index theorem as observable = Real(abstract structure)"
  putStrLn "  Gauss-Bonnet: int c_1(T Sigma_g) = chi(Sigma_g) = 2 - 2g"
  mapM_ (\g ->
           let s = Surface g
           in printf "      genus %d : chi = %2d , tangent Chern number = %2d\n"
                     g (eulerCharacteristicSurface s) (tangentChernNumber s))
        [0, 1, 2, 3]
  putStrLn "  Riemann-Roch (Dolbeault index): ind = deg L + 1 - g  = int ch(L) Td(T Sigma)"
  mapM_ (\(g, d) ->
           let s   = Surface g
               idx = riemannRochIndex s d
               ok  = indexEqualsTopological s d
           in printf "      Sigma_%d , deg L = %2d : ind = %3d  (observable = Real ? %s)\n"
                     g d idx (checkMark ok))
        [(0, 0), (0, 3), (1, 0), (1, 5), (2, 4)]

-- ---------------------------------------------------------------------------
-- 5. Equational-reasoning proof checks (module "Proofs")
-- ---------------------------------------------------------------------------

demoProofs :: IO Bool
demoProofs = do
  banner "5. Equational-reasoning proof checks (Proofs.hs)"
  oks <- mapM runProof allProofs
  let passed = length (filter id oks)
      total  = length oks
  printf "  proofs checked: %d / %d passed\n" passed total
  pure (and oks)
  where
    runProof :: (String, Either String ()) -> IO Bool
    runProof (name, res) = case res of
      Right () -> do
        printf "  [%-4s] %s\n" "OK" name
        pure True
      Left err -> do
        printf "  [%-4s] %s\n" "FAIL" name
        putStrLn ("        -> " ++ err)
        pure False

-- ---------------------------------------------------------------------------

main :: IO ()
main = do
  putStrLn "Algebraic Topology: Conserved Global Information (Part IV)"
  putStrLn "Companion demonstrations -- YonedaAI Research Collective"
  demoHomology
  demoTQFT
  demoDW
  demoIndex
  proofsOK <- demoProofs
  banner "All demonstrations complete."
  unless proofsOK exitFailure
