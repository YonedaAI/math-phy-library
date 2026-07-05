-- | Module      : DerivedCritical
--   Description : The derived critical locus dCrit(S) as the BV field/antifield
--                 algebra (Theorem 8.7 / T4 of Part III).
--
--   For a smooth scheme @X@ of dimension @n@ and an action functional
--   @S : X -> A^1@, the derived critical locus is modelled by the Koszul
--   complex of the differential @dS@:
--
--     * its structure complex is @Lambda^bullet T_X@ with @Lambda^p T_X@ placed
--       in cohomological degree @-p@ (Theorem 8.7(2)): degree @0@ carries the
--       fields @O_X@, degrees @-1,-2,...@ carry the antifields
--       @T_X, Lambda^2 T_X, ...@; the Koszul differential @iota_{dS}@ raises
--       cohomological degree by @+1@;
--     * NO positive-degree generators appear -- there are no ghosts for a bare
--       scheme (Remark "schemes give antifields, stacks give ghosts"). Ghosts
--       (degrees @1..m@) appear only for the gauge STACK @[X/G]@, resolving an
--       @m@-dimensional gauge symmetry -- modelled here by 'stackComplexDegrees';
--     * its classical truncation is @pi_0(dCrit(S)) = Crit(S)@ with
--       @H^0 = O_X/(dS) = R/I@, the on-shell observable algebra (Theorem 8.7(1)),
--       which we reuse directly from "Scheme".onShell;
--     * it carries a canonical @(-1)@-shifted symplectic form whose antibracket
--       sits in cohomological degree @-1@ (PTVV).
--
--   This is a finite, combinatorial model sufficient to exhibit and test the
--   degree bookkeeping and the classical truncation of Theorem 8.7.
module DerivedCritical
  ( DerivedCritical            -- abstract: build only via 'mkDerivedCriticalSafe'
  , mkDerivedCriticalSafe
  , isValidDim
  , ambientDim
  , koszulDegrees
  , koszulRanks
  , koszulTotalRank
  , koszulDifferentialDegree
  , classicalCrit
  , hasGhosts
  , ghostDegrees
  , stackComplexDegrees
  , hasGhostsStack
  , antibracketDegree
  , freeScalar
  ) where

import Scheme (CoordRing(..), Ideal(..), Poly(..), Var, onShell)

-- | A (model of a) derived critical locus @dCrit(S)@: the smooth ambient scheme
--   presented by its coordinate ring @R = O_X@, its smooth dimension
--   @n = dim X@ (stored explicitly, since @dim X@ need not equal the number of
--   ring generators once relations are present), and the ideal @(dS)@ of
--   equations of motion (the components of the differential of the action).
data DerivedCritical = DerivedCritical
  { ambientRing :: CoordRing   -- ^ @R = O_X@ (fields live here, degree 0)
  , smoothDim   :: Int         -- ^ @n = dim X@ (rank of the tangent bundle)
  , dAction     :: Ideal       -- ^ @(dS)@, the ideal of equations of motion
  } deriving (Show)

-- | The ambient dimension @n = dim X = rank(T_X)@.
ambientDim :: DerivedCritical -> Int
ambientDim = smoothDim

-- | A smooth dimension is valid when it is non-negative (a scheme cannot have
--   negative dimension).
isValidDim :: Int -> Bool
isValidDim n = n >= 0

-- | Build a derived critical locus from an ambient coordinate ring, its smooth
--   dimension, and the differential @dS@ of the action. Precondition:
--   @dim >= 0@ (use 'mkDerivedCriticalSafe' to enforce it).
mkDerivedCritical :: CoordRing -> Int -> Ideal -> DerivedCritical
mkDerivedCritical = DerivedCritical

-- | Validated smart constructor: reject a negative smooth dimension outright,
--   so invalid states cannot silently produce an empty Koszul complex.
mkDerivedCriticalSafe :: CoordRing -> Int -> Ideal -> Maybe DerivedCritical
mkDerivedCriticalSafe r n i
  | isValidDim n = Just (DerivedCritical r n i)
  | otherwise    = Nothing

-- | The cohomological degrees carried by the Koszul complex
--   @Lambda^bullet T_X@ of Theorem 8.7(2): @Lambda^p T_X@ sits in degree @-p@,
--   so the degrees present are @[0, -1, ..., -n]@ for @n = dim X@.
--
--   Every degree is @<= 0@: this is precisely the "no ghosts" statement for a
--   bare scheme (positive-degree ghosts appear only for a stack @[X/G]@).
koszulDegrees :: DerivedCritical -> [Int]
koszulDegrees dc = [ negate p | p <- [0 .. ambientDim dc] ]

-- | The cohomological degree by which the Koszul differential @iota_{dS}@ shifts:
--   it maps @Lambda^p T_X -> Lambda^{p-1} T_X@, i.e. degree @-p -> -(p-1)@, a
--   shift of @+1@.
koszulDifferentialDegree :: Int
koszulDifferentialDegree = 1

-- | Binomial coefficient @C(n,k)@ (multiplicative form, exact on 'Integer').
binomial :: Int -> Int -> Integer
binomial n k
  | k < 0 || k > n = 0
  | otherwise      = product [ fromIntegral (n - k + i) | i <- [1 .. k] ]
                       `div` product [ fromIntegral i | i <- [1 .. k] ]

-- | Ranks of the graded pieces of the Koszul complex: @rank(Lambda^p T_X)
--   = C(n,p)@, listed by ascending @p = 0 .. n@ (i.e. in the same order as the
--   degrees @0, -1, ..., -n@).
koszulRanks :: DerivedCritical -> [Integer]
koszulRanks dc = [ binomial n p | p <- [0 .. n] ]
  where n = ambientDim dc

-- | Total rank of @Lambda^bullet T_X@, which is @2^n@ (the sum of the graded
--   ranks). A structural check on the Koszul bookkeeping.
koszulTotalRank :: DerivedCritical -> Integer
koszulTotalRank = sum . koszulRanks

-- | The classical truncation @pi_0(dCrit(S)) = Crit(S)@, whose coordinate ring
--   is @H^0 = O_X/(dS) = R/I@ (Theorem 8.7(1)). Realised by adjoining the
--   equations of motion @(dS)@ to the relations of @R@ -- exactly the on-shell
--   observable algebra of "Scheme".onShell.
classicalCrit :: DerivedCritical -> CoordRing
classicalCrit dc = onShell (ambientRing dc) (dAction dc)

-- | Whether the complex has ghosts (positive-degree generators). For a bare
--   scheme this is always 'False' (Theorem 8.7(2) / the ghosts remark).
hasGhosts :: DerivedCritical -> Bool
hasGhosts dc = any (> 0) (koszulDegrees dc)

-- | The BRST ghost degrees @g[1]@ contributed by resolving a gauge group of
--   dimension @m@: the positive cohomological degrees @1..m@ (Remark on ghosts).
--   A non-positive gauge dimension contributes no ghosts.
ghostDegrees :: Int -> [Int]
ghostDegrees m = [1 .. max 0 m]

-- | The cohomological degrees of the full BV-BRST complex of the derived
--   critical locus of the STACK @[X/G]@: ghosts @g[1]@ (degrees @1..m@) on top
--   of the field/antifield degrees @0..-n@ of the bare scheme. This is where
--   Theorem 8.3 (stacks retain gauge data) and Theorem 8.7 meet.
stackComplexDegrees :: Int -> Int -> [Int]
stackComplexDegrees n m = ghostDegrees m ++ [ negate p | p <- [0 .. n] ]

-- | Whether resolving an @m@-dimensional gauge symmetry introduces ghosts:
--   'True' exactly when @m > 0@. Contrast with 'hasGhosts' for a bare scheme.
hasGhostsStack :: Int -> Bool
hasGhostsStack m = any (> 0) (ghostDegrees m)

-- | The cohomological degree of the BV antibracket: the @(-1)@-shifted
--   symplectic form of PTVV lives in degree @-1@.
antibracketDegree :: Int
antibracketDegree = -1

-- | The free real scalar (Section 6.3 flavour): @X = A^1 = Spec k[phi]@, action
--   @S = phi^2/2@, so @dS = (phi)@ and @Crit(S) = {phi = 0}@. The Koszul
--   resolution here already computes the (reduced) intersection.
freeScalar :: DerivedCritical
freeScalar = mkDerivedCritical ring 1 dS
  where
    ring :: CoordRing
    ring = CoordRing { generators = ["phi"], relations = [] }
    dS :: Ideal
    dS = Ideal [ Poly [ (1, [(phiVar, 1)]) ] ]  -- dS = phi
    phiVar :: Var
    phiVar = "phi"
