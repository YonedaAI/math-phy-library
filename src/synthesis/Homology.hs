-- | Module      : Homology
--   Part VII (Synthesis), Part IV face: conserved global information.
--
--   A small but honest chain-complex calculator over the field @GF(2)@.  We
--   implement Gaussian elimination to get ranks of the boundary maps, hence
--   Betti numbers @b_n = dim C_n - rank d_n - rank d_{n+1}@, and we verify the
--   defining relation @d_n . d_{n+1} = 0@.
--
--   The load-bearing instance for the synthesis is the orientable genus-@g@
--   surface Sigma_g, whose minimal CW structure (1 vertex, 2g edges, 1 face)
--   gives @b_1(Sigma_g; Z_2) = 2g@.  This is the topological input to the
--   surface-code logical dimension @2^{2g}@ (synthesis PVI/T3, eq. mf8):
--   logical operators are the classes of @H_1(Sigma_g; Z_2)@ (synthesis
--   Sec. "Homology reused literally").
module Homology
  ( -- * GF(2) linear algebra
    Vec
  , Mat
  , rankGF2
  , matMulGF2
  , isZeroMat
  , kernelBasisGF2
    -- * Chain complexes
  , ChainComplex(..)
  , wellFormed
  , dimAt
  , boundaryRank
  , betti
  , boundarySquaredZero
  , eulerFromDims
  , eulerFromBetti
    -- * Concrete complexes
  , genusSurface
  , circleAsTriangle
  , filledTriangle
    -- * Surface-code topology (PVI/T3)
  , h1Rank
  , surfaceCodeLogicalDim
  ) where

import Data.List      (transpose)
import Numeric.Natural (Natural)

-- | A vector over @GF(2)@.
type Vec = [Bool]

-- | A matrix over @GF(2)@ stored as a list of rows.  A boundary map
--   @d_{k+1} : C_{k+1} -> C_k@ is stored with @dim C_k@ rows and
--   @dim C_{k+1}@ columns.
type Mat = [[Bool]]

-- | Addition in @GF(2)@ is exclusive-or.
bxor :: Bool -> Bool -> Bool
bxor = (/=)

-- | Rank of a @GF(2)@ matrix via Gaussian elimination over columns.
rankGF2 :: Mat -> Int
rankGF2 []            = 0
rankGF2 rows@(r0 : _) = goCols [0 .. length r0 - 1] rows
  where
    goCols :: [Int] -> Mat -> Int
    goCols []       _  = 0
    goCols _        [] = 0
    goCols (c : cs) rs =
      case break (\r -> r !! c) rs of
        (_, [])                -> goCols cs rs           -- no pivot in column c
        (before, pivot : after) ->
          let rest    = before ++ after
              reduced = map (\r -> if r !! c then zipWith bxor r pivot else r) rest
          in 1 + goCols cs reduced

-- | Matrix product over @GF(2)@ (@a@ is @m x k@, @b@ is @k x n@).
matMulGF2 :: Mat -> Mat -> Mat
matMulGF2 a b = [ [ dotRow row col | col <- transpose b ] | row <- a ]
  where
    dotRow :: Vec -> Vec -> Bool
    dotRow xs ys = foldr bxor False (zipWith (&&) xs ys)

-- | Is every entry @0@?
isZeroMat :: Mat -> Bool
isZeroMat = all (all not)

-- | Reduced row echelon form of a @GF(2)@ matrix with @n@ columns, returned as
--   the list of @(pivot column, fully reduced row)@ pairs.
rrefGF2 :: Int -> Mat -> [(Int, Vec)]
rrefGF2 n = go 0 []
  where
    go :: Int -> [(Int, Vec)] -> Mat -> [(Int, Vec)]
    go col acc rs
      | col >= n  = reverse acc
      | otherwise =
          case break (\r -> r !! col) rs of
            (_, [])            -> go (col + 1) acc rs
            (before, piv : after) ->
              let elim r      = if r !! col then zipWith bxor r piv else r
                  rest        = map elim (before ++ after)
                  accReduced  = [ (pc, elim rowv) | (pc, rowv) <- acc ]
              in go (col + 1) ((col, piv) : accReduced) rest

-- | A basis of the null space @{ x | A x = 0 }@ of a @GF(2)@ matrix @A@ with
--   @n@ columns, each basis vector given as a length-@n@ 'Vec'.  Used to build
--   genuine chain complexes (image of @d_{k+1}@ inside the kernel of @d_k@).
kernelBasisGF2 :: Int -> Mat -> [Vec]
kernelBasisGF2 n rows =
  [ [ coord f col | col <- [0 .. n - 1] ] | f <- frees ]
  where
    pivs :: [(Int, Vec)]
    pivs = rrefGF2 n rows

    pivCols :: [Int]
    pivCols = map fst pivs

    frees :: [Int]
    frees = [ c | c <- [0 .. n - 1], c `notElem` pivCols ]

    coord :: Int -> Int -> Bool
    coord f col
      | col == f  = True
      | otherwise = maybe False (\rowv -> rowv !! f) (lookup col pivs)

-- | A finite chain complex over @GF(2)@: the dimensions of @C_0, C_1, ...@ and
--   the boundary matrices, where @ccBoundaries !! k@ is
--   @d_{k+1} : C_{k+1} -> C_k@.
data ChainComplex = ChainComplex
  { ccDims       :: [Int]  -- ^ dims of @C_0, C_1, ...@
  , ccBoundaries :: [Mat]  -- ^ @ccBoundaries !! k = d_{k+1}@
  } deriving (Eq, Show)

-- | Structural well-formedness: each boundary matrix @d_{k+1}@ has exactly
--   @dim C_k@ rows and @dim C_{k+1}@ columns (no ragged or dimension-mismatched
--   matrices).
wellFormed :: ChainComplex -> Bool
wellFormed cc =
  and [ shapeOk k | k <- [0 .. length (ccBoundaries cc) - 1] ]
  where
    shapeOk :: Int -> Bool
    shapeOk k =
      let m    = ccBoundaries cc !! k
          rows = dimAt cc k
          cols = dimAt cc (k + 1)
      in length m == rows && all (\r -> length r == cols) m

-- | @dim C_n@ (zero outside the recorded range).
dimAt :: ChainComplex -> Int -> Int
dimAt cc n
  | n >= 0 && n < length (ccDims cc) = ccDims cc !! n
  | otherwise                        = 0

-- | Rank of @d_k@.  By convention @d_0 = 0@ and boundaries beyond the recorded
--   range vanish.
boundaryRank :: ChainComplex -> Int -> Int
boundaryRank cc k
  | k <= 0                            = 0
  | k - 1 < length (ccBoundaries cc)  = rankGF2 (ccBoundaries cc !! (k - 1))
  | otherwise                         = 0

-- | The @n@-th Betti number @b_n = dim C_n - rank d_n - rank d_{n+1}@.
betti :: ChainComplex -> Int -> Int
betti cc n = dimAt cc n - boundaryRank cc n - boundaryRank cc (n + 1)

-- | The defining relation of a chain complex: @d_k . d_{k+1} = 0@ for all @k@.
boundarySquaredZero :: ChainComplex -> Bool
boundarySquaredZero cc =
  and [ isZeroMat (matMulGF2 (bmat k) (bmat (k + 1)))
      | k <- [1 .. length (ccBoundaries cc) - 1]
      ]
  where
    bmat :: Int -> Mat
    bmat j = ccBoundaries cc !! (j - 1)

-- | Euler characteristic as the alternating sum of the chain-group dimensions.
eulerFromDims :: ChainComplex -> Int
eulerFromDims cc =
  sum [ signAt n * dimAt cc n | n <- [0 .. length (ccDims cc) - 1] ]
  where
    signAt :: Int -> Int
    signAt n = if even n then 1 else (-1)

-- | Euler characteristic as the alternating sum of Betti numbers.  Equals
--   'eulerFromDims' for any chain complex (rank-nullity), independently of
--   whether @d^2 = 0@ -- this is the QuickCheck-checkable Euler relation.
eulerFromBetti :: ChainComplex -> Int
eulerFromBetti cc =
  sum [ signAt n * betti cc n | n <- [0 .. hi] ]
  where
    hi :: Int
    hi = max (length (ccDims cc) - 1) (length (ccBoundaries cc))

    signAt :: Int -> Int
    signAt n = if even n then 1 else (-1)

-- | The minimal CW structure of the orientable genus-@g@ surface:
--   one 0-cell, @2g@ 1-cells, one 2-cell.  Over @GF(2)@ both boundary maps
--   vanish (every 1-cell is a loop; the attaching word of the 2-cell uses each
--   generator an even number of times), so @b_0 = 1@, @b_1 = 2g@, @b_2 = 1@.
--   The genus is a 'Natural', so a negative genus is unrepresentable.
genusSurface :: Natural -> ChainComplex
genusSurface g = ChainComplex
  { ccDims       = [1, 2 * gi, 1]
  , ccBoundaries = [ zeros 1 (2 * gi)   -- d_1 : C_1 -> C_0
                   , zeros (2 * gi) 1    -- d_2 : C_2 -> C_1
                   ]
  }
  where
    gi :: Int
    gi = fromIntegral g

    zeros :: Int -> Int -> Mat
    zeros r c = replicate r (replicate c False)

-- | The circle presented as the boundary of a triangle: 3 vertices, 3 edges,
--   no 2-cell.  @b_0 = 1@, @b_1 = 1@.  Provides a non-trivial @d_1@.
circleAsTriangle :: ChainComplex
circleAsTriangle = ChainComplex
  { ccDims       = [3, 3]
  , ccBoundaries = [ d1 ]
  }
  where
    -- edges e01, e12, e20 ; columns are edges, rows are vertices v0,v1,v2.
    d1 :: Mat
    d1 =
      [ [ True,  False, True  ]  -- v0 is in e01 and e20
      , [ True,  True,  False ]  -- v1 is in e01 and e12
      , [ False, True,  True  ]  -- v2 is in e12 and e20
      ]

-- | The filled triangle (a 2-disk): 'circleAsTriangle' with a single 2-cell
--   glued along all three edges.  Contractible: @b_0 = 1@, @b_1 = b_2 = 0@,
--   and @d_1 . d_2 = 0@ holds non-trivially.
filledTriangle :: ChainComplex
filledTriangle = ChainComplex
  { ccDims       = [3, 3, 1]
  , ccBoundaries = [ ccBoundaries circleAsTriangle !! 0
                   , d2
                   ]
  }
  where
    d2 :: Mat  -- the 2-cell is bounded by all three edges
    d2 = [ [True], [True], [True] ]

-- | Rank of @H_1(Sigma_g; Z_2)@, i.e. @2g@, computed via GF(2) Gaussian
--   elimination.  This is the number @k@ of logical qubits of the genus-@g@
--   surface code (synthesis PVI/T3).  Returned as a 'Natural' (always @>= 0@).
h1Rank :: Natural -> Natural
h1Rank g = fromIntegral (betti (genusSurface g) 1)

-- | Logical Hilbert-space dimension of the genus-@g@ surface code,
--   @2^{2g} = 2^{rank H_1(Sigma_g; Z_2)}@ (synthesis eq. mf8, PVI/T3).
surfaceCodeLogicalDim :: Natural -> Integer
surfaceCodeLogicalDim g = (2 :: Integer) ^ h1Rank g
