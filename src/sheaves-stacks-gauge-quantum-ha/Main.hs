-- | Module      : Main
--   Part VI of "A Math->Physics Representation Library":
--   "Sheaves, Stacks, Gauge Redundancy, and Quantum High-Availability".
--
--   Runnable demonstration of the paper's four principal results:
--
--     T1  Stacks retain isotropy:  Aut_{[X/G]}(x) = Stab_G(x), and the
--         orbifold Euler characteristic (a stack-only observable) is computed.
--     T2  Descent/sheaf gluing witnessed on a small site.
--     T3  Surface-code logical qubits = rank H_1(Sigma_g; Z_2) = 2g;
--         code space dimension = 2^{2g}.
--     T4  Connes--Kreimer coproduct and antipode on rooted trees.
--
--   Build:  ghc -O0 Main.hs -o demo   (all modules in this directory)
--   Run  :  ./demo
module Main (main) where

import Sheaf
import Stack
import Stabilizer
import Hopf
import QHA
import Proofs (runAllProofs)

import Data.Ratio (numerator, denominator)
import System.Exit (exitFailure)

-- ---------------------------------------------------------------------------
-- T1 : gauge redundancy Z/2 acting on {-1, 0, 1} by negation.
--   Orbits: {-1,1} (free) and {0} (fixed, stabilizer = whole group).
-- ---------------------------------------------------------------------------

z2Negation :: GaugeAction Int Bool
z2Negation = GaugeAction
  { act      = \g x -> if g then negate x else x   -- True = nontrivial element
  , elements = [False, True]
  }

demoT1 :: IO ()
demoT1 = do
  putStrLn "== T1: stacks retain isotropy  Aut_[X/G](x) = Stab_G(x) =="
  let pts = [-1, 0, 1] :: [Int]
  mapM_ (\x -> do
            let (orb, stab) = stackQuotient z2Negation x
            putStrLn $ "  x = " ++ show x
                    ++ "  orbit = " ++ show orb
                    ++ "  |Stab| = " ++ show (length stab)
                    ++ "  (= |Aut_[X/G](x)|)")
        pts
  putStrLn $ "  coarse quotient forgets the |Stab| at x=0 (nontrivial isotropy)."
  putStrLn $ "  free action? " ++ show (isFreeAction z2Negation pts)
                                ++ "  (False: x=0 is fixed)"
  let chi = orbifoldEulerChar z2Negation pts
  putStrLn $ "  orbifold Euler char (stack-only observable) = "
           ++ show (numerator chi) ++ "/" ++ show (denominator chi)
           ++ "  (= 1/2 for {-1,1} + 1/1 for {0} = 3/2)"

-- ---------------------------------------------------------------------------
-- T2 : sheaf gluing on a two-set cover of {1,2}.
-- ---------------------------------------------------------------------------

-- A presheaf that is NOT a sheaf: local sections A,B exist on each piece of an
-- overlapping cover of the connected base {1,2,3}, but the only global section G
-- restricts to A everywhere.  The compatible family [B,B] therefore has no
-- global preimage: descent fails.
gappyPresheaf :: Presheaf String
gappyPresheaf = Presheaf
  { sections = \u -> if u == [1, 2, 3] then ["G"] else ["A", "B"]
  , restrict = \small big s ->
      if big == [1, 2, 3]
        then "A"
        else if small == [2]
               then if s == "A" then "p" else "q"
               else s
  }

demoT2 :: IO ()
demoT2 = do
  putStrLn "\n== T2: descent -- compatible local sections glue iff sheaf =="
  -- (a) The constant presheaf on a CONNECTED single-piece cover is a sheaf.
  let pf   = constantPresheaf ["a", "b"] :: Presheaf String
      conn = Cover [[1, 2]]
      cfam = [ [v] | v <- ["a", "b"] ]
  putStrLn $ "  constant presheaf, connected cover {1,2}:"
  putStrLn $ "    separated? " ++ show (isSeparated pf conn)
           ++ "   every compatible fam glues? " ++ show (glues pf conn cfam)
           ++ "   sheaf? " ++ show (isSheafFor pf conn cfam)
  -- (b) A genuine NON-sheaf: compatible local data with no global glue.
  let gcov = Cover [[1, 2], [2, 3]]
      bad  = ["B", "B"]
  putStrLn $ "  gappy presheaf, overlapping cover {1,2},{2,3}:"
  putStrLn $ "    family [B,B] compatible on overlap {2}? "
           ++ show (compatible gappyPresheaf gcov bad)
  putStrLn $ "    does it glue? " ++ show (glues gappyPresheaf gcov [bad])
           ++ "   sheaf? " ++ show (isSheafFor gappyPresheaf gcov [bad])
           ++ "   (False: descent obstruction)"

-- ---------------------------------------------------------------------------
-- T3 : surface code -- logical qubits = 2g = rank H_1(Sigma_g; Z_2).
-- ---------------------------------------------------------------------------

demoT3 :: IO ()
demoT3 = do
  putStrLn "\n== T3: surface-code logical operators = H_1(Sigma_g; Z_2) =="
  mapM_ (\g -> do
            let k   = surfaceCodeLogicalQubits g
                r   = h1Rank g
                dim = (2 :: Integer) ^ k
            putStrLn $ "  genus g = " ++ show g
                    ++ "  logical qubits k = " ++ show k
                    ++ "  rank H_1 = " ++ show r
                    ++ "  dim(code) = 2^" ++ show k ++ " = " ++ show dim
                    ++ (if k == r then "   [k = rank H_1  OK]" else "  MISMATCH"))
        [0, 1, 2, 3]
  -- a tiny explicit stabilizer code: two commuting single-qubit-support ops
  let code = StabilizerCode
        { numQubits  = 3
        , generators = [ Pauli [0,0,0] [1,1,0]     -- Z_1 Z_2
                       , Pauli [0,0,0] [0,1,1] ]    -- Z_2 Z_3
        }
  putStrLn $ "  toy [[3,1]] code: k = " ++ show (numLogicalQubits code)
           ++ ", dim = " ++ show (codeSpaceDim code)
           ++ ", generators commute? " ++ show (surfaceCodeCommuting code)

-- ---------------------------------------------------------------------------
-- T4 : Connes--Kreimer coproduct and antipode.
-- ---------------------------------------------------------------------------

-- the "cherry": a root with two leaf children (3 vertices)
cherry :: RootedTree
cherry = Node [Node [], Node []]

-- the "ladder" of length 2: root - child - grandchild
ladder2 :: RootedTree
ladder2 = Node [Node [Node []]]

demoT4 :: IO ()
demoT4 = do
  putStrLn "\n== T4: Connes--Kreimer coproduct & antipode (renormalization) =="
  let single = Node [] :: RootedTree
  putStrLn $ "  single vertex primitive? " ++ show (counitPrimitive single)
           ++ "  (Delta = t(x)1 + 1(x)t only)"
  putStrLn $ "  cherry: #vertices = " ++ show (nodes cherry)
           ++ ", #coproduct terms = " ++ show (length (coproduct cherry))
  putStrLn $ "  cherry antipode terms  S(t) = "
           ++ show (antipode cherry)
  putStrLn $ "  ladder2 antipode terms S(t) = "
           ++ show (antipode ladder2)
  putStrLn $ "  Hopf antipode axiom m(S(x)id)Delta = 0 holds on:"
  putStrLn $ "     single vertex? " ++ show (verifyAntipodeAxiom (Node []))
           ++ "   cherry? " ++ show (verifyAntipodeAxiom cherry)
           ++ "   ladder2? " ++ show (verifyAntipodeAxiom ladder2)
  putStrLn $ "  (antipode = BPHZ counterterm; recursion S(t) = -t - sum S(P^c) R^c)"

-- ---------------------------------------------------------------------------
-- QHA subsystem decomposition demo.
-- ---------------------------------------------------------------------------

demoQHA :: IO ()
demoQHA = do
  putStrLn "\n== QHA: H_phys ~= (H_log (x) H_gauge) (+) H_err =="
  let enc = QHAEncoding
        { embed        = id
        , equivalences = [id]
        , syndromeOf   = const trivialSyndrome
        , correctable  = \_ -> Just id
        , dimLogical   = 2      -- one logical qubit
        , dimGauge     = 2      -- one gauge qubit
        , dimError     = 4      -- error sectors
        } :: QHAEncoding Int Int
  putStrLn $ "  dim H_phys = " ++ show (subsystemDim enc)
           ++ "  (= 2*2 + 4)"
  putStrLn $ "  availability (redundancy) = " ++ show (availability enc)

main :: IO ()
main = do
  putStrLn "Sheaves, Stacks, Gauge Redundancy, and Quantum High-Availability"
  putStrLn "Part VI -- runnable demonstrations of T1-T4"
  putStrLn (replicate 64 '-')
  demoT1
  demoT2
  demoT3
  demoT4
  demoQHA
  putStrLn (replicate 64 '-')
  proofsOk <- runAllProofs
  putStrLn (replicate 64 '-')
  if proofsOk
    then putStrLn "done: all equational proof checks passed."
    else do
      putStrLn "FAIL: some equational proof checks failed."
      exitFailure
