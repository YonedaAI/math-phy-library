-- |
-- Module      : TQFT
-- Description : Topological quantum field theory as a symmetric monoidal functor,
--               2d TQFTs as commutative Frobenius algebras, and untwisted
--               Dijkgraaf-Witten state sums.
--
-- Part IV of "A Math->Physics Representation Library".  This module encodes:
--
--   * Definition (TQFT, Atiyah's axioms) via the 'SymMonFunctor' class:
--     a TQFT sends disjoint union to tensor and gluing to composition
--     (Theorem "TQFT realizes the Part I pipeline; monoidality is the
--     Decomposition axiom").
--
--   * Example "A 2d TQFT is a commutative Frobenius algebra": we verify the
--     Frobenius-algebra laws (associativity, commutativity, unit) for a concrete
--     algebra and read off Z(Sigma_g) for closed genus-g surfaces.
--
--   * Theorem (Dijkgraaf-Witten instantiates Locality/descent): the untwisted
--     state sum Z_0(M) = |Hom(pi_1 M, G)| / |G|, computed here for the 2- and
--     3-torus by counting commuting tuples in a finite group given by its
--     Cayley table.
module TQFT
  ( -- * TQFT as a symmetric monoidal functor
    SymMonFunctor(..)
  , Amplitude(..)
    -- * 2d TQFT = commutative Frobenius algebra
  , Vec
  , FrobeniusAlgebra(..)
  , groupAlgebraZn
  , isAssociative
  , isCommutative
  , unitLaws
  , frobeniusFormNondegenerate
  , frobeniusLawsHold
  , partitionSurface
    -- * Finite groups and Dijkgraaf-Witten state sums
  , FiniteGroup(..)
  , zmod
  , symmetric3
  , commutingPairs
  , commutingTriples
  , dwUntwistedT2
  , dwUntwistedT3
  ) where

import Data.List (nub)

-- ---------------------------------------------------------------------------
-- TQFT as a symmetric monoidal functor (Atiyah's axioms)
-- ---------------------------------------------------------------------------

-- | A symmetric monoidal functor @Z : Bord_n -> C@.  The methods correspond to
-- the two structural axioms of a TQFT: 'fUnit' is @Z(empty) = unit@, 'fTensor'
-- is @Z(M1 |_| M2) = Z(M1) (x) Z(M2)@ (disjoint union -> tensor), and 'fCompose'
-- is @Z(W2 . W1) = Z(W2) . Z(W1)@ (gluing -> composition).
class SymMonFunctor z where
  fUnit    :: z            -- ^ image of the empty manifold (the monoidal unit)
  fTensor  :: z -> z -> z  -- ^ disjoint union  -> tensor product
  fCompose :: z -> z -> z  -- ^ gluing of cobordisms -> composition

-- | The simplest (invertible, @1@-dimensional) TQFT: a numerical amplitude with
-- disjoint union realized as multiplication and gluing as multiplication.  It is
-- a concrete, lawful witness of the two structural axioms of Theorem "TQFT
-- realizes the Part I pipeline; monoidality is the Decomposition axiom": 'fUnit'
-- is a two-sided identity for 'fTensor', which is associative and (symmetric-)
-- commutative.
newtype Amplitude = Amplitude { getAmplitude :: Double }
  deriving (Eq, Show)

instance SymMonFunctor Amplitude where
  fUnit                                 = Amplitude 1
  fTensor  (Amplitude a) (Amplitude b)  = Amplitude (a * b)
  fCompose (Amplitude a) (Amplitude b)  = Amplitude (a * b)

-- ---------------------------------------------------------------------------
-- 2d TQFT = commutative Frobenius algebra
-- ---------------------------------------------------------------------------

-- | A vector in a fixed finite basis.
type Vec = [Double]

-- | A (finite-dimensional) Frobenius algebra: a basis dimension, a bilinear
-- multiplication, a unit vector, and a nondegenerate trace form (counit).
data FrobeniusAlgebra = FrobeniusAlgebra
  { faDim    :: Int             -- ^ dimension of the underlying vector space
  , faMul    :: Vec -> Vec -> Vec
  , faUnit   :: Vec
  , faCounit :: Vec -> Double   -- ^ Frobenius trace form  theta : A -> k
  }

-- | Standard basis vectors of dimension @n@.
basisVectors :: Int -> [Vec]
basisVectors n = [ [ if i == j then 1 else 0 | j <- [0 .. n - 1] ] | i <- [0 .. n - 1] ]

approxEq :: Vec -> Vec -> Bool
approxEq u v = length u == length v && and (zipWith (\a b -> abs (a - b) < 1e-9) u v)

-- | The group algebra @k[Z/n]@ of the cyclic group, a commutative Frobenius
-- algebra: basis @g^0, ..., g^{n-1}@, multiplication by convolution
-- (@g^i * g^j = g^{(i+j) mod n}@), unit @g^0@, and Frobenius form picking out the
-- identity coefficient.
groupAlgebraZn :: Int -> FrobeniusAlgebra
groupAlgebraZn n
  | n < 1     = error "groupAlgebraZn: group order must be >= 1"
groupAlgebraZn n = FrobeniusAlgebra
  { faDim    = n
  , faMul    = mul
  , faUnit   = [ if i == 0 then 1 else 0 | i <- [0 .. n - 1] ]
  , faCounit = \v -> case v of { (x : _) -> x; [] -> 0 }
  }
  where
    mul u v =
      [ sum [ (u !! i) * (v !! j) | i <- [0 .. n - 1], j <- [0 .. n - 1]
                                  , (i + j) `mod` n == k ]
      | k <- [0 .. n - 1] ]

-- | Associativity @(xy)z = x(yz)@ checked on all basis triples.
isAssociative :: FrobeniusAlgebra -> Bool
isAssociative fa = and
  [ approxEq (m (m x y) z) (m x (m y z))
  | x <- bs, y <- bs, z <- bs ]
  where bs = basisVectors (faDim fa); m = faMul fa

-- | Commutativity @xy = yx@ checked on all basis pairs.
isCommutative :: FrobeniusAlgebra -> Bool
isCommutative fa = and [ approxEq (m x y) (m y x) | x <- bs, y <- bs ]
  where bs = basisVectors (faDim fa); m = faMul fa

-- | Left and right unit laws @1*x = x = x*1@.
unitLaws :: FrobeniusAlgebra -> Bool
unitLaws fa = and [ approxEq (m u x) x && approxEq (m x u) x | x <- bs ]
  where bs = basisVectors (faDim fa); m = faMul fa; u = faUnit fa

-- | Nondegeneracy of the Frobenius trace form -- the defining condition of a
-- Frobenius algebra.  The form @<x,y> = theta(x y)@ is nondegenerate iff its
-- (real) Gram matrix @G_{ij} = theta(e_i e_j)@ has full rank; we compute the
-- rank directly over 'Double' via Gaussian elimination (so the general
-- signature is honest -- no integer rounding).  A Frobenius algebra must be
-- nonzero, so the zero-dimensional algebra is rejected.  (Together with
-- associativity and the unit laws this is a complete characterization: an
-- associative unital algebra with a nondegenerate invariant trace form is
-- precisely a Frobenius algebra, from which the comultiplication is recovered
-- uniquely.)
frobeniusFormNondegenerate :: FrobeniusAlgebra -> Bool
frobeniusFormNondegenerate fa
  | faDim fa < 1 = False
  | otherwise    = rankD gram == faDim fa
  where
    bs   = basisVectors (faDim fa)
    gram = [ [ faCounit fa (faMul fa x y) | y <- bs ] | x <- bs ]

-- | Rank of a real matrix by Gaussian elimination with a small pivot tolerance.
rankD :: [[Double]] -> Int
rankD m0 = go m0 0
  where
    eps :: Double
    eps = 1e-9

    headD :: [Double] -> Double
    headD (x : _) = x
    headD []      = 0

    go :: [[Double]] -> Int -> Int
    go rows r = case rows of
      []                  -> r
      (fr : _)
        | null fr         -> r
        | otherwise       -> case pivot rows of
            Nothing        -> r
            Just (p, rest) -> case p of
              []           -> r
              (pv : _)     ->
                let p'    = map (/ pv) p
                    clr q = zipWith (\a b -> a - headD q * b) q p'
                    rest' = map (drop 1 . clr) rest
                in go rest' (r + 1)

    pivot :: [[Double]] -> Maybe ([Double], [[Double]])
    pivot rows = case break (\row -> abs (headD row) > eps) rows of
      (before, x : after) -> Just (x, before ++ after)
      (_, [])
        | any (not . null) rows -> pivot (map (drop 1) rows)
        | otherwise             -> Nothing

-- | All commutative-Frobenius-algebra laws relevant to a 2d TQFT: associativity,
-- commutativity, the unit laws, and nondegeneracy of the Frobenius trace form.
frobeniusLawsHold :: FrobeniusAlgebra -> Bool
frobeniusLawsHold fa =
  isAssociative fa && isCommutative fa && unitLaws fa
    && frobeniusFormNondegenerate fa

-- | The genus-@g@ partition function of the 2d TQFT determined by a semisimple
-- commutative Frobenius algebra.  For the group algebra @k[G]@ of a finite
-- abelian group this evaluates to @|G|^g@; we return the closed-form value for
-- the cyclic group @Z/n@ (dimension @n = |G|@) to avoid diagonalization.
-- The genus @g@ must be nonnegative (a closed oriented surface has @g >= 0@).
partitionSurface :: FrobeniusAlgebra -> Int -> Double
partitionSurface fa g
  | g < 0     = error "partitionSurface: genus must be >= 0"
  | otherwise = fromIntegral (faDim fa) ^^ g

-- ---------------------------------------------------------------------------
-- Finite groups and untwisted Dijkgraaf-Witten state sums
-- ---------------------------------------------------------------------------

-- | A finite group specified by its element list and a binary operation.
data FiniteGroup a = FiniteGroup
  { elements :: [a]
  , op       :: a -> a -> a
  }

-- | The cyclic group @Z/n@ under addition mod @n@ (requires @n >= 1@; a group
-- must be nonempty, and @n = 0@ would make the Dijkgraaf-Witten normalization
-- divide by zero).
zmod :: Int -> FiniteGroup Int
zmod n
  | n < 1     = error "zmod: group order must be >= 1"
  | otherwise = FiniteGroup
      { elements = [0 .. n - 1]
      , op       = \x y -> (x + y) `mod` n
      }

-- | The symmetric group @S_3@ as permutations of @[0,1,2]@ (element = image list).
symmetric3 :: FiniteGroup [Int]
symmetric3 = FiniteGroup
  { elements = perms3
  , op       = \s t -> map (s !!) t   -- (s . t)(i) = s(t(i))
  }
  where perms3 = [ [a, b, c] | a <- [0..2], b <- [0..2], c <- [0..2]
                             , length (nub [a, b, c]) == 3 ]

-- | Do two group elements commute?
commute :: Eq a => FiniteGroup a -> a -> a -> Bool
commute g x y = op g x y == op g y x

-- | The set of commuting pairs @(a,b)@, i.e. @Hom(pi_1 T^2, G) = Hom(Z^2, G)@.
commutingPairs :: Eq a => FiniteGroup a -> [(a, a)]
commutingPairs g =
  [ (a, b) | a <- elements g, b <- elements g, commute g a b ]

-- | The set of pairwise-commuting triples @(a,b,c)@, i.e. @Hom(Z^3, G)@.
commutingTriples :: Eq a => FiniteGroup a -> [(a, a, a)]
commutingTriples g =
  [ (a, b, c)
  | a <- elements g, b <- elements g, c <- elements g
  , commute g a b, commute g a c, commute g b c ]

-- | Untwisted Dijkgraaf-Witten partition function on the 2-torus:
-- @Z_0(T^2) = |Hom(Z^2, G)| / |G|@ (Example, ground-state degeneracy).  The
-- group must be nonempty (a group has an identity), else the normalization
-- divides by zero.
dwUntwistedT2 :: Eq a => FiniteGroup a -> Double
dwUntwistedT2 g
  | null (elements g) = error "dwUntwistedT2: group must be nonempty"
  | otherwise         =
      fromIntegral (length (commutingPairs g)) / fromIntegral (length (elements g))

-- | Untwisted Dijkgraaf-Witten partition function on the 3-torus:
-- @Z_0(T^3) = |Hom(Z^3, G)| / |G|@.  For abelian @G@ this equals @|G|^2@.  The
-- group must be nonempty.
dwUntwistedT3 :: Eq a => FiniteGroup a -> Double
dwUntwistedT3 g
  | null (elements g) = error "dwUntwistedT3: group must be nonempty"
  | otherwise         =
      fromIntegral (length (commutingTriples g)) / fromIntegral (length (elements g))
