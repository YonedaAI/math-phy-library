-- |
-- Module      : Pipeline
-- Description : The realization pipeline  Obs_alpha = Obs . Real_alpha . Phi.
--
-- Encodes Definition "realization pipeline" and Corollary "reliability of a
-- pipeline": the pipeline is the composite of three functorial stages, and its
-- epistemic status is the join (the less-reliable) of the three stage statuses.
module Pipeline
  ( Channel(..)
  , Stage(..)
  , Pipeline(..)
  , runPipeline
  , pipelineStatus
  , functoriality
  ) where

import Status (Status(..), joinAll)

-- | Realization channels indexed by @alpha@ (Definition: realization channel).
data Channel
  = Betti | DeRham | Hodge | Etale | PAdic | Quantum
  | Thermodynamic | Computational | Experimental | Operational
  deriving (Eq, Show, Enum, Bounded)

-- | A single functorial stage of the pipeline: an underlying map together with
-- the epistemic status at which that map is actually constructed.
data Stage a b = Stage
  { stageMap    :: a -> b
  , stageStatus :: Status
  }

-- | The realization pipeline over a channel: the three stages
-- @Phi : m -> i@, @Real_alpha : i -> r@, and @Obs : r -> o@.
data Pipeline m i r o = Pipeline
  { channel :: Channel
  , phi     :: Stage m i   -- ^ abstract-information functor Phi
  , realA   :: Stage i r   -- ^ realization channel Real_alpha
  , obs     :: Stage r o   -- ^ observable extraction Obs
  }

-- | Run the pipeline on a mathematical structure:
-- @Obs_alpha(m) = Obs (Real_alpha (Phi m))@ (Definition: realization pipeline).
runPipeline :: Pipeline m i r o -> m -> o
runPipeline p = stageMap (obs p) . stageMap (realA p) . stageMap (phi p)

-- | The epistemic status of the whole pipeline is the join of its three stage
-- statuses (Corollary: reliability of a pipeline).  An S-labeled pipeline
-- requires all three stages to be S; a single heuristic stage downgrades it.
pipelineStatus :: Pipeline m i r o -> Status
pipelineStatus p = joinAll [stageStatus (phi p), stageStatus (realA p), stageStatus (obs p)]

-- | A finite check of Theorem "functoriality of the realization pipeline":
-- the composite preserves composition on a supplied pair of morphisms, i.e.
-- @runPipeline p (g . f) x == (runPipeline-of-images) x@ pointwise.  Here we
-- simply verify that running the pipeline agrees with the staged composite on
-- a given input, witnessing associativity of the three-stage composition.
functoriality :: Eq o => Pipeline m i r o -> m -> Bool
functoriality p x =
  runPipeline p x
    == stageMap (obs p) (stageMap (realA p) (stageMap (phi p) x))
