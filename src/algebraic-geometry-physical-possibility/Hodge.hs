{-# LANGUAGE ScopedTypeVariables #-}

-- | Module      : Hodge
--   Description : Variations of Hodge structure with a Gauss-Manin connection,
--                 encoding the family realization pipeline of Part III
--                 (Definition 6.2, Theorem 8.1 / T1). The FLAT sections of the
--                 Gauss-Manin connection are the Betti cycles; the period is the
--                 pairing of such a flat cycle with the (non-flat) holomorphic
--                 form, and it satisfies the Picard-Fuchs ODE.
--
--   We give a lightweight numerical model sufficient to *exhibit* the
--   structure: a rank-r local system over a 1-dimensional base, a decreasing
--   Hodge filtration, a Gauss-Manin connection matrix, and the Picard-Fuchs
--   operator that annihilates the period functions. The Legendre family
--   of elliptic curves (Example 6.4) is the worked instance.
module Hodge
  ( Base
  , ConnectionMatrix
  , VHS(..)
  , griffithsOK
  , griffithsAt
  , flatStep
  , picardFuchsLegendre
  , legendreVHS
  , transportPeriod
  , transportTrajectory
  ) where

import Data.List (partition)

-- | A 1-dimensional analytic base parameter (e.g. the Legendre lambda).
type Base = Double

-- | The (solution-side) Gauss-Manin connection matrix A(s): the period vector v
--   against a flat homology frame is a horizontal section, solving d/ds v = A(s) v.
--   (Equivalently A is the connection matrix of the dual of Gauss-Manin on H_dR,
--   whose own flat sections are the Betti cycles.)
type ConnectionMatrix = Base -> [[Double]]

-- | A variation of Hodge structure over a 1-dimensional base:
--   * fiber       : dimension of the local system (rank r),
--   * hodgeFiltr  : the decreasing Hodge filtration F^p at each base point,
--   * gaussManin  : the connection matrix A(s),
--   * transversal : a Boolean witness of Griffiths transversality.
data VHS = VHS
  { rank        :: Int
  , hodgeFiltr  :: Base -> [[[Double]]] -- F^0 >= F^1 >= ...; each F^p a matrix
                                        -- (list of basis row-vectors)
  , gaussManin  :: ConnectionMatrix
  , transversal :: Bool
  }

-- | Griffiths transversality, as a recorded Boolean witness on the VHS.
griffithsOK :: VHS -> Bool
griffithsOK = transversal

-- | The numeric rank of a real matrix (rows as vectors), by Gaussian
--   elimination with a small pivot tolerance. Used to decide subspace
--   membership below.
numericRank :: [[Double]] -> Int
numericRank rows =
  case rows of
    []        -> 0
    (r0 : _)
      | null r0   -> 0
      | otherwise ->
          let (pivots, rest) = partition (\row -> abs (firstOf row) > eps) rows
          in case pivots of
               []       -> numericRank (map (drop 1) rows)      -- first column all zero
               (p : ps) ->
                 let elim row = zipWith (\a b -> a - (firstOf row / firstOf p) * b) row p
                     reduced  = map (drop 1 . elim) (ps ++ rest)
                 in 1 + numericRank reduced
  where
    eps = 1e-9
    firstOf xs = case xs of { (y : _) -> y; [] -> 0 }

-- | Whether the vector @w@ lies in the row span of @basis@ (rank does not
--   increase when @w@ is adjoined).
inRowSpan :: [[Double]] -> [Double] -> Bool
inRowSpan basis w = numericRank (basis ++ [w]) == numericRank basis

-- | Griffiths transversality, COMPUTED from the actual filtration and connection
--   data at a base point (rather than merely read off the stored Boolean):
--
--     * @F^0@ has full rank @r@ (it is the whole fibre) and the connection is an
--       @r x r@ matrix;
--     * the Hodge filtration is decreasing (@dim F^p >= dim F^{p+1}@);
--     * for each adjacent pair @F^p supseteq F^{p-1}@, the Gauss-Manin connection
--       carries every vector of @F^p@ into the row span of @F^{p-1}@ -- an actual
--       subspace-membership test per level (Definition 6.2:
--       nabla F^p subseteq F^{p-1} tensor Omega^1).
griffithsAt :: VHS -> Base -> Bool
griffithsAt vhs lam =
  case hodgeFiltr vhs lam of
    fs@(f0 : _) ->
      let dims  = map length fs
          r     = rank vhs
          a     = gaussManin vhs lam
          -- adjacent pairs (F^p, F^{p-1}) with p>=1: the deeper level and the
          -- one it must transport into.
          pairs = zip (drop 1 fs) fs
      in numericRank f0 == r                            -- F^0 spans the fibre
         && length a == r && all ((== r) . length) a    -- connection is r x r
         && and (zipWith (>=) dims (drop 1 dims))         -- filtration decreasing
         && all (\(fp, fprev) ->
                   all (\v -> length v == r
                              && inRowSpan fprev (matVec a v)) fp)
                pairs
    [] -> False
  where matVec m x = [ sum (zipWith (*) row x) | row <- m ]

-- | One explicit Euler step of the first-order Gauss-Manin system
--   v(s+h) = v(s) + h A(s) v(s), i.e. dv/ds = A(s) v. Here v is the vector of
--   periods against a flat homology frame; it solves d v = A v (Theorem 8.1(1)).
--   NOTE: the periods are NOT flat sections (nabla Pi /= 0 in general); the flat
--   sections are the Betti cycles, and A encodes the non-flatness of the form.
flatStep :: ConnectionMatrix -> Double -> Base -> [Double] -> [Double]
flatStep aMat h s v = zipWith (+) v (map (* h) (matVec (aMat s) v))
  where matVec m x = [ sum (zipWith (*) row x) | row <- m ]

-- | The Picard-Fuchs operator of the Legendre family (Example 6.4):
--     lambda(1-lambda) f'' + (1 - 2 lambda) f' - (1/4) f = 0.
--   Returned as its coefficient functions (c2, c1, c0) so that
--   c2 f'' + c1 f' + c0 f = 0.
picardFuchsLegendre :: Base -> (Double, Double, Double)
picardFuchsLegendre lam =
  ( lam * (1 - lam)      -- coefficient of f''
  , 1 - 2 * lam          -- coefficient of f'
  , -0.25                -- coefficient of f
  )

-- | The Legendre VHS: rank-2 local system R^1 pi_* Q over
--   P^1 \ {0,1,infinity}. The connection matrix is the companion matrix of the
--   Picard-Fuchs operator, so that the period vector is a horizontal section of
--   this solution-side connection (and each component solves Picard-Fuchs).
legendreVHS :: VHS
legendreVHS = VHS
  { rank        = 2
  , hodgeFiltr  = \_ -> [ [ [1,0], [0,1] ]   -- F^0 = whole H^1 (rank 2)
                        , [ [1,0] ] ]        -- F^1 = holomorphic line (rank 1)
  , gaussManin  = companion
  , transversal = True                        -- Griffiths transversality holds
  }
  where
    -- companion matrix of  f'' = -(c1/c2) f' - (c0/c2) f, avoiding the
    -- singular locus lambda in {0,1}.
    companion lam =
      let (c2, c1, c0) = picardFuchsLegendre lam
          safe = if abs c2 < 1e-9 then 1e-9 else c2
      in [ [ 0,          1        ]
         , [ -c0 / safe, -c1 / safe ] ]

-- | Transport an initial period vector from lambda0 to lambda1 in n Euler
--   steps by solving the first-order Gauss-Manin system d(Pi) = A Pi -- a
--   concrete (non-constant) period function of the Legendre VHS (Theorem 8.1).
transportPeriod :: VHS -> Base -> Base -> Int -> [Double] -> [Double]
transportPeriod vhs lam0 lam1 n v0
  | n <= 0    = v0                       -- reject non-positive step counts
  | otherwise = foldl step v0 [0 .. n - 1]
  where
    h = (lam1 - lam0) / fromIntegral n
    step v k = flatStep (gaussManin vhs) h (lam0 + fromIntegral k * h) v

-- | The full transported trajectory @[Pi(lam0), ..., Pi(lam1)]@ (n+1 states) of
--   the first-order Gauss-Manin system, exposed so that a period solution can be
--   validated dynamically against its Picard-Fuchs equation by finite
--   differences (rather than only via the algebraic companion identity).
transportTrajectory :: VHS -> Base -> Base -> Int -> [Double] -> [[Double]]
transportTrajectory vhs lam0 lam1 n v0
  | n <= 0    = [v0]
  | otherwise = scanl step v0 [0 .. n - 1]
  where
    h = (lam1 - lam0) / fromIntegral n
    step v k = flatStep (gaussManin vhs) h (lam0 + fromIntegral k * h) v
