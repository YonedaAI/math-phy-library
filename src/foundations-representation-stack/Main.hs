-- |
-- Module      : Main
-- Description : Runnable demonstrations of the representation-stack foundations.
--
-- Demonstrates the key results of Part I:
--
--   1. The status calculus (Theorem: status calculus): composing an S entry
--      with an H entry yields H; a single speculative stage collapses a chain
--      to P.
--   2. The realization pipeline (Definition: realization pipeline) as a
--      three-stage composite, with the TQFT pipeline (Example: TQFT as a
--      status-S pipeline) computing to status S.
--   3. Corollary "reliability of a pipeline": the pipeline status is the join
--      (the less-reliable) of its three stage statuses.
--   4. Coarse-quotient loses gauge information (Theorem: coarse-quotient
--      obstruction), illustrated on a toy groupoid of entries.
module Main (main) where

import Status
import RepStack
import Pipeline
import Proofs (runProofs)
import Data.List (nub)
import System.Exit (exitFailure)
import Control.Monad (unless)

-- ------------------------------------------------------------------
-- Toy carrier types standing in for Math_d, Info_d, Rep_d, Meas_d.
-- ------------------------------------------------------------------

-- | A toy "mathematical structure" in the algebraic-topology domain.
newtype Manifold = Manifold { dimOf :: Int } deriving (Eq, Show)

-- | Abstract bordism information Phi(M): the class of a manifold.
newtype Bordism = Bordism Int deriving (Eq, Show)

-- | A toy physical representation: a vector space recorded by its dimension.
newtype VecSpace = VecSpace Int deriving (Eq, Show)

-- | A measurement datum: a partition-function-like number.
newtype PartFn = PartFn Int deriving (Eq, Show)

-- ------------------------------------------------------------------
-- Demonstration 1: the status calculus.
-- ------------------------------------------------------------------

demoStatusCalculus :: IO ()
demoStatusCalculus = do
  putStrLn "== Demonstration 1: status calculus (S < H < P) =="
  -- An S entry: an honest functor (built through the well-formedness-enforcing
  -- smart constructor 'mkRepEntry').
  let eS :: RepEntry Int Int
      eS = mkRepEntry 3 6 (FunctorialTranslation (* 2)) Std
  -- An H entry: an interpretive rule.
  let eH :: RepEntry Int Int
      eH = mkRepEntry 6 7 (InterpretiveRule (\x -> Just (x + 1))) Heur
  -- A P entry: a speculative (possibly partial) map.
  let eP :: RepEntry Int Int
      eP = mkRepEntry 7 0 (SpeculativeMap (const (Just 0))) Spec
  let sSH  = status (composeEntry eH eS)
  let sSHP = status (composeEntry eP (composeEntry eH eS))
  putStrLn $ "  status(H . S)       = " ++ show sSH  ++ "   (expected Heur)"
  putStrLn $ "  status(P . H . S)   = " ++ show sSHP ++ "   (expected Spec)"
  putStrLn $ "  join is idempotent: Heur `joinStatus` Heur = " ++ show (joinStatus Heur Heur)
  putStrLn $ "  Std is the unit:    Std `joinStatus` Spec   = " ++ show (joinStatus Std Spec)
  putStrLn ""

-- ------------------------------------------------------------------
-- Demonstration 2 & 3: the realization pipeline and its reliability.
-- ------------------------------------------------------------------

-- | The TQFT pipeline of Example "TQFT as a status-S pipeline": every stage is
-- an honestly-constructed functor, so the whole pipeline is status S.
tqftPipeline :: Pipeline Manifold Bordism VecSpace PartFn
tqftPipeline = Pipeline
  { channel = Quantum
  , phi   = Stage (\(Manifold d) -> Bordism d)          Std
  , realA = Stage (\(Bordism d)  -> VecSpace (2 ^ d))    Std   -- Z : Bord -> Vect
  , obs   = Stage (\(VecSpace n) -> PartFn n)            Std
  }

-- | A degraded pipeline: the realization stage is only heuristic, so by the
-- reliability corollary the whole pipeline is H.
heuristicPipeline :: Pipeline Manifold Bordism VecSpace PartFn
heuristicPipeline = tqftPipeline
  { realA = Stage (\(Bordism d) -> VecSpace (2 ^ d)) Heur }

demoPipeline :: IO ()
demoPipeline = do
  putStrLn "== Demonstration 2/3: realization pipeline Obs . Real_alpha . Phi =="
  let m = Manifold 3
  putStrLn $ "  channel                     = " ++ show (channel tqftPipeline)
  putStrLn $ "  Obs_alpha(Manifold 3)       = " ++ show (runPipeline tqftPipeline m)
  putStrLn $ "  functoriality check         = " ++ show (functoriality tqftPipeline m)
  putStrLn $ "  status(TQFT pipeline)       = " ++ show (pipelineStatus tqftPipeline)
              ++ "   (expected Std)"
  putStrLn $ "  status(heuristic pipeline)  = " ++ show (pipelineStatus heuristicPipeline)
              ++ "   (expected Heur)"
  putStrLn ""

-- ------------------------------------------------------------------
-- Demonstration 4: coarse quotient loses gauge information.
-- ------------------------------------------------------------------

-- We model a groupoid of entries over one domain as a list of objects together
-- with a gauge action.  The coarse quotient identifies gauge-related objects;
-- when the gauge action is nontrivial, distinct global gluings collapse to one
-- coarse class, illustrating Theorem "coarse-quotient obstruction".

-- | Objects of a toy groupoid: configurations labelled by an integer.  We use
-- 'Integer' (not 'Int') so that the gauge action @n |-> -n@ has no fixed point
-- other than 0 --- 'Int' would have the pathology @negate minBound == minBound@.
newtype Config = Config Integer deriving (Eq, Show)

-- | A nontrivial gauge automorphism (a Z/2 action) on configurations.
gauge :: Config -> Config
gauge (Config n) = Config (negate n)

-- | The coarse quotient: identify a config with its gauge image by taking a
-- canonical representative (the absolute value).
coarseClass :: Config -> Integer
coarseClass (Config n) = abs n

demoCoarseQuotient :: IO ()
demoCoarseQuotient = do
  putStrLn "== Demonstration 4: coarse quotient forgets gauge/automorphism data =="
  let configs      = [Config 1, Config (-1), Config 2]
  let distinctFine = length (nub configs)
  let distinctCoarse = length (nub (map coarseClass configs))
  putStrLn $ "  configurations                 = " ++ show configs
  putStrLn $ "  gauge Z/2 acts by n |-> -n; e.g. gauge (Config 1) = "
              ++ show (gauge (Config 1))
  putStrLn $ "  # distinct fine (stack) objects  = " ++ show distinctFine
  putStrLn $ "  # distinct coarse classes        = " ++ show distinctCoarse
  putStrLn $ "  => the coarse quotient merged "
              ++ show (distinctFine - distinctCoarse)
              ++ " gauge-related object(s): automorphism data is lost."
  putStrLn ""

-- ------------------------------------------------------------------

main :: IO ()
main = do
  putStrLn "Foundations: Representation Stack and Realization Pipeline (Part I)"
  putStrLn "Runnable demonstrations of the key results.\n"
  demoStatusCalculus
  demoPipeline
  demoCoarseQuotient
  putStrLn "All demonstrations complete.\n"
  ok <- runProofs
  putStrLn ""
  unless ok $ do
    putStrLn "PROOF CHECK FAILED."
    exitFailure
  putStrLn "All equational proof checks passed."
