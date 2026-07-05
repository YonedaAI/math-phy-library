{-# LANGUAGE ScopedTypeVariables #-}

-- | Module      : Scheme
--   Description : Schemes as functors of points, with coordinate rings and
--                 the on-shell observable algebra R/I of Part III, Section 3.
--
--   Part III of the modular series "A Math->Physics Representation Library".
--   We model a scheme by its functor of points R |-> Hom(Spec R, X)
--   (Remark 3.6 / "functor of points"), a commutative ring by a finite
--   presentation (generators + relations), and the on-shell observable
--   algebra R/I (Definition 3.1 / Example 3.2) by adjoining the ideal of
--   constraints to the relations.
module Scheme
  ( Var
  , Poly(..)
  , CoordRing(..)
  , Ideal(..)
  , RPoint(..)
  , Scheme(..)
  , onShell
  , wellFormedPoly
  , wellFormedRing
  , wellFormedIdeal
  , affineLine
  , dualNumbers
  , specPoints
  , massShell
  ) where

import Data.List (nub)

-- | Variables are named symbols.
type Var = String

-- | A very small polynomial model: a sum of monomials, each a rational
--   coefficient times a product of powers of variables. Enough to *present*
--   coordinate rings and constraint ideals symbolically; we do not implement
--   a Groebner engine (the paper's claims are structural, not computational).
newtype Poly = Poly { monomials :: [(Rational, [(Var, Int)])] }
  deriving (Eq)

instance Show Poly where
  show (Poly []) = "0"
  show (Poly ms) = unwords (map showMon ms)
    where
      showMon (c, []) = show c
      showMon (c, vs) = show c ++ "*" ++ concatMap showPow vs
      showPow (v, 1) = v
      showPow (v, n) = v ++ "^" ++ show n

-- | A commutative ring presented by generators and a relation set.
--   Physically: the coordinate ring is the algebra of observables; the
--   generators are the fields/coordinates, the relations the equations they
--   already satisfy.
data CoordRing = CoordRing
  { generators :: [Var]
  , relations  :: [Poly]
  } deriving (Show, Eq)

-- | An ideal, presented by a generating set of polynomials: the constraint
--   equations (equations of motion / conservation laws).
newtype Ideal = Ideal { idealGens :: [Poly] }
  deriving (Eq)

instance Show Ideal where
  show (Ideal gs) = "(" ++ unwords (map show gs) ++ ")"

-- | An R-point of a scheme: a symbolic assignment of ring elements to the
--   generators (a k-algebra homomorphism out of the coordinate ring).
newtype RPoint = RPoint { coords :: [(Var, String)] } deriving (Show, Eq)

-- | A scheme exposed via its functor of points: R |-> Hom(Spec R, X).
--   Given a ring of "test parameters" it returns the set of configurations
--   parametrised by that ring. Nilpotents in the test ring make infinitesimal
--   (tangent) directions visible -- the whole point of schemes over varieties.
newtype Scheme = Scheme { pointsOver :: CoordRing -> [RPoint] }

-- | The on-shell observable algebra R/I (Definition 3.1, Example 3.2):
--   functions modulo the ideal of physical constraints. We model the quotient
--   by adjoining the constraint generators to the relations of R.
onShell :: CoordRing -> Ideal -> CoordRing
onShell r i = r { relations = relations r ++ idealGens i }

-- | A polynomial over a variable set @vars@ is well-formed when every monomial
--   uses only variables of @vars@, with strictly positive exponents and no
--   repeated variable within a monomial. This rejects the malformed inputs
--   (negative exponents, duplicate variables, out-of-ring variables) that a raw
--   @[(Rational,[(Var,Int)])]@ would otherwise silently admit.
wellFormedPoly :: [Var] -> Poly -> Bool
wellFormedPoly vars (Poly ms) = all okMonomial ms
  where
    okMonomial :: (Rational, [(Var, Int)]) -> Bool
    okMonomial (_, powers) =
         all (\(v, e) -> e >= 1 && v `elem` vars) powers
      && let vs = map fst powers in length vs == length (nub vs)

-- | A coordinate ring is well-formed when its generators are distinct and every
--   relation is a well-formed polynomial over those generators.
wellFormedRing :: CoordRing -> Bool
wellFormedRing r =
     length gs == length (nub gs)
  && all (wellFormedPoly gs) (relations r)
  where gs = generators r

-- | An ideal is well-formed over a ring when the ring itself is well-formed and
--   every generator is a well-formed polynomial over the ring's variables.
wellFormedIdeal :: CoordRing -> Ideal -> Bool
wellFormedIdeal r i =
  wellFormedRing r && all (wellFormedPoly (generators r)) (idealGens i)

-- | The affine line A^1 = Spec k[x]: coordinate ring with one generator, no
--   relations.
affineLine :: CoordRing
affineLine = CoordRing { generators = ["x"], relations = [] }

-- | The dual numbers k[e]/(e^2): a nonreduced test ring whose points detect
--   first-order deformations (tangent vectors). Its presence in the functor of
--   points is exactly what distinguishes a scheme from a variety.
dualNumbers :: CoordRing
dualNumbers = CoordRing
  { generators = ["e"]
  , relations  = [ Poly [(1, [("e", 2)])] ]  -- e^2 = 0
  }

-- | A toy "Spec" enumeration: over the dual numbers, the affine line has the
--   points {x = 0, x = e}, exhibiting the nonzero tangent space of Spec k[x].
--   (Symbolic demonstration, not a decision procedure.)
specPoints :: Scheme
specPoints = Scheme $ \testRing ->
  if "e" `elem` generators testRing
    then [ RPoint [("x", "0")], RPoint [("x", "e")] ]  -- tangent vector visible
    else [ RPoint [("x", "0")] ]

-- | The mass-shell constraint E - p^2/(2m) = 0 as an ideal on R = k[q,p,E].
--   onShell (freeParticle) massShell models "imposing the mass-shell
--   condition": E becomes a function of p on-shell.
massShell :: Ideal
massShell = Ideal
  [ Poly [ (1, [("E", 1)])
         , (-1, [("p", 2)])   -- schematic 1/(2m) absorbed into the coefficient
         ] ]
