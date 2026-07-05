-- |
-- Module      : ChainComplex
-- Description : Chain complexes, the boundary operator, and rational homology.
-- Part IV of "A Math->Physics Representation Library": Algebraic Topology,
-- Conserved Global Information.
--
-- This module encodes Definition (Chain complex) and Definition (Homology) from
-- the companion paper.  A chain complex is a sequence of free abelian groups
-- @C_0, C_1, ...@ with boundary maps @d_n : C_n -> C_{n-1}@ satisfying the
-- fundamental relation @d_{n-1} . d_n = 0@ (Lemma "Boundaries are cycles").
-- Over the rationals, the n-th Betti number is
--
-- >  b_n = dim C_n - rank d_n - rank d_{n+1}.
--
-- We represent boundary maps as integer matrices and compute ranks by Gaussian
-- elimination over 'Double' (rational rank).
module ChainComplex
  ( Matrix
  , ChainComplex(..)
  , boundaryAt
  , matMul
  , isZeroMatrix
  , numRows
  , numCols
  , isRectangular
  , conformable
  , wellFormed
  , dSquaredIsZero
  , rankQ
  , bettiNumbers
  , eulerCharacteristic
  , alternatingSumDims
  -- * Simplicial layer (faithful boundary operator)
  , Simplex
  , IntChain
  , deleteAt
  , simplexChain
  , boundarySimplex
  , boundaryChain
  , normalizeChain
  , closure
  , cone
  , fromSimplicialComplex
  -- * Concrete complexes
  , circle
  , torus
  , sphere2
  , pointSpace
  ) where

import Data.List (transpose, sort, subsequences)

-- | An integer matrix in row-major form. The matrix @m@ representing a boundary
-- map @d_k : C_k -> C_{k-1}@ has @dim C_{k-1}@ rows and @dim C_k@ columns.
type Matrix = [[Int]]

-- | A finite chain complex: @dims !! n@ is @dim C_n@, and @boundaries !! (k-1)@
-- is the matrix of @d_k : C_k -> C_{k-1}@ for @k >= 1@.
data ChainComplex = ChainComplex
  { dims       :: [Int]      -- ^ dimensions of C_0, C_1, ...
  , boundaries :: [Matrix]   -- ^ d_1, d_2, ... (d_k : C_k -> C_{k-1})
  } deriving (Eq, Show)

-- | The boundary matrix @d_k@; @d_0@ and any out-of-range @d_k@ are the zero map
-- with the appropriate shape.
boundaryAt :: ChainComplex -> Int -> Matrix
boundaryAt cc k
  | k <= 0                       = replicate 0 []              -- d_0 = 0
  | k <= length (boundaries cc)  = boundaries cc !! (k - 1)
  | otherwise                    = []                          -- zero map above top

-- | Matrix multiplication over the integers.
matMul :: Matrix -> Matrix -> Matrix
matMul a b
  | null a           = []
  | null b           = replicate (length a) []
  | otherwise        = [ [ sum (zipWith (*) row col) | col <- cols ] | row <- a ]
  where cols = transpose b

-- | Is every entry of a matrix zero?
isZeroMatrix :: Matrix -> Bool
isZeroMatrix = all (all (== 0))

-- | The number of rows of a matrix.
numRows :: Matrix -> Int
numRows = length

-- | The number of columns of a matrix (@0@ for a matrix with no rows).
numCols :: Matrix -> Int
numCols []      = 0
numCols (r : _) = length r

-- | Is a matrix rectangular (all rows the same length)?
isRectangular :: Matrix -> Bool
isRectangular []       = True
isRectangular (r : rs) = all ((== length r) . length) rs

-- | Are two matrices conformable for the product @a * b@, i.e. does the number
-- of columns of @a@ equal the number of rows of @b@?  This is required for
-- @a * b@ to be well defined; 'matMul' would otherwise silently truncate.
conformable :: Matrix -> Matrix -> Bool
conformable a b = numCols a == numRows b

-- | A chain complex is /well formed/ when it has one boundary map per gap in
-- 'dims', every boundary matrix is rectangular with the shape dictated by the
-- dimensions (@d_k@ has @dim C_{k-1}@ rows and @dim C_k@ columns), and
-- consecutive maps are conformable.  Betti numbers and @d^2=0@ are only
-- meaningful for well-formed complexes; this guards against malformed input.
wellFormed :: ChainComplex -> Bool
wellFormed cc =
  not (null (dims cc))
    && all (>= 0) (dims cc)
    && length (boundaries cc) == length (dims cc) - 1
    && all shapeOK [1 .. length (boundaries cc)]
    && all consecutiveOK [2 .. length (boundaries cc)]
  where
    d k = boundaries cc !! (k - 1)
    shapeOK k =
      let m = d k
      in isRectangular m
         && numRows m == dims cc !! (k - 1)
         -- a zero-row matrix cannot record its column count, so only demand the
         -- column shape when there is at least one row.
         && (numRows m == 0 || numCols m == dims cc !! k)
    consecutiveOK k = conformable (d (k - 1)) (d k)

-- | Verify the fundamental relation @d_{k-1} . d_k = 0@ for all consecutive
-- boundary maps.  This is Lemma "Boundaries are cycles" / Lemma "Singular
-- boundary squares to zero" at the level of the given presentation.  The
-- composition is required to be dimension-conformable, so a malformed complex
-- whose maps would only appear to square to zero under silent truncation is
-- correctly reported as failing (returns 'False').  The complex must first be
-- 'wellFormed' (correctly shaped against 'dims'); otherwise the certification is
-- meaningless and we return 'False'.
dSquaredIsZero :: ChainComplex -> Bool
dSquaredIsZero cc = wellFormed cc && all ok [2 .. length (boundaries cc)]
  where
    ok k =
      let dk   = boundaryAt cc k         -- C_k   -> C_{k-1}
          dk1  = boundaryAt cc (k - 1)   -- C_{k-1} -> C_{k-2}
      in isRectangular dk && isRectangular dk1
         && conformable dk1 dk
         && isZeroMatrix (matMul dk1 dk)

-- | Rank of an integer matrix computed /exactly/ over the rationals via
-- Gaussian elimination.  Entries are lifted into @'Rational'@ (arbitrary
-- precision), so there is no floating-point error: pivots are compared against
-- @0@ exactly.  We repeatedly locate a pivot in the first column; if the whole
-- first column vanishes we strip it (the rank is unchanged) and recurse.
rankQ :: Matrix -> Int
rankQ m0 = go (map (map fromIntegral) m0) 0
  where
    firstEntry :: [Rational] -> Rational
    firstEntry (x : _) = x
    firstEntry []      = 0

    go :: [[Rational]] -> Int -> Int
    go rows r =
      case rows of
        []                    -> r
        (firstR : _)
          | null firstR       -> r                      -- no columns left
          | otherwise ->
              case pivotRow rows of
                Nothing            -> r                  -- first column all zero
                Just (p, rest)     ->
                  case p of
                    []             -> r
                    (piv : _)      ->
                      let p'      = map (/ piv) p
                          clear q = zipWith (\a b -> a - firstEntry q * b) q p'
                          rest'   = map (drop 1 . clear) rest
                      in go rest' (r + 1)

    -- Find a row whose first entry is nonzero; return it plus the other rows.
    -- If the whole first column is zero (but columns remain), strip it and retry.
    pivotRow :: [[Rational]] -> Maybe ([Rational], [[Rational]])
    pivotRow rows =
      case break (\row -> firstEntry row /= 0) rows of
        (before, x : after) -> Just (x, before ++ after)
        (_, [])
          | any (not . null) rows -> pivotRow (map (drop 1) rows)
          | otherwise             -> Nothing

-- | Betti numbers @b_0, b_1, ..., b_top@ over the rationals:
-- @b_n = dim C_n - rank d_n - rank d_{n+1}@.  These are the ranks of the
-- homology groups and are only meaningful when the complex is 'wellFormed' and
-- 'dSquaredIsZero' holds; on a malformed complex the returned numbers are
-- garbage (and may be negative).
bettiNumbers :: ChainComplex -> [Int]
bettiNumbers cc =
  [ (dims cc !! n) - rankQ (boundaryAt cc n) - rankQ (boundaryAt cc (n + 1))
  | n <- [0 .. length (dims cc) - 1] ]

-- | Euler characteristic as the alternating sum of Betti numbers (equivalently
-- of the dimensions, by rank-nullity): @chi = sum (-1)^n b_n@.
eulerCharacteristic :: ChainComplex -> Int
eulerCharacteristic cc =
  sum (zipWith (*) (cycle [1, -1]) (bettiNumbers cc))

-- | The alternating sum of the /dimensions/ @sum (-1)^n dim C_n@.  The
-- Euler-Poincare theorem states this equals 'eulerCharacteristic' (the
-- alternating sum of Betti numbers); this is a conserved topological invariant.
alternatingSumDims :: ChainComplex -> Int
alternatingSumDims cc = sum (zipWith (*) (cycle [1, -1]) (dims cc))

-- ---------------------------------------------------------------------------
-- Simplicial layer: the faithful alternating-face boundary operator
-- (Lemma "Singular boundary squares to zero", Def. "Homology")
-- ---------------------------------------------------------------------------

-- | An (abstract) oriented simplex is a strictly increasing list of vertices;
-- @[v_0, ..., v_k]@ represents a @k@-simplex.
type Simplex = [Int]

-- | A simplicial @k@-chain: a formal integer combination of @k@-simplices,
-- stored as @(coefficient, simplex)@ pairs.
type IntChain = [(Int, Simplex)]

-- | The elementary chain @1 . s@ carried by a single simplex.
simplexChain :: Simplex -> IntChain
simplexChain s = [(1, s)]

-- | Delete the element at position @i@ (0-based); positions out of range leave
-- the list unchanged.
deleteAt :: Int -> [a] -> [a]
deleteAt i xs = [ x | (j, x) <- zip [0 :: Int ..] xs, j /= i ]

-- | The boundary of a single simplex as the alternating sum of its faces,
-- @partial [v_0,...,v_k] = sum_i (-1)^i [v_0,...,hat v_i,...,v_k]@.  The boundary
-- of a vertex (or the empty simplex) is @0@, giving the /non-reduced/ chain
-- complex (Def. "Homology", singular boundary specialized to simplices).
boundarySimplex :: Simplex -> IntChain
boundarySimplex s
  | length s <= 1 = []
  | otherwise     =
      [ (if even i then 1 else -1, deleteAt i s) | i <- [0 .. length s - 1] ]

-- | Extend 'boundarySimplex' linearly to chains and collect like terms.
boundaryChain :: IntChain -> IntChain
boundaryChain c =
  normalizeChain
    [ (a * b, t) | (a, s) <- c, (b, t) <- boundarySimplex s ]

-- | Put a chain in canonical form: combine coefficients of equal simplices,
-- drop zero coefficients, and sort.  Two chains are equal iff their canonical
-- forms are equal, so @normalizeChain c == []@ certifies @c = 0@.
normalizeChain :: IntChain -> IntChain
normalizeChain c =
  [ (v, s) | s <- keys, let v = sum [ a | (a, t) <- c, t == s ], v /= 0 ]
  where
    keys = sortUniq (map snd c)

-- | Sort and remove duplicates (adjacent-dedup after sorting).
sortUniq :: Ord a => [a] -> [a]
sortUniq = foldr dedup [] . sort
  where
    dedup :: Eq a => a -> [a] -> [a]
    dedup x (y : ys) | x == y = y : ys
    dedup x ys                = x : ys

-- | The downward closure of a set of simplices: all nonempty faces of every
-- listed simplex, sorted and de-duplicated.  This turns any list of "maximal
-- faces" into a genuine abstract simplicial complex.
closure :: [Simplex] -> [Simplex]
closure = sortUniq . concatMap (filter (not . null) . map sort . subsequences)

-- | The simplicial cone on a complex: adjoin a fresh apex vertex and join it to
-- every face.  The cone is always contractible, so its homology is that of a
-- point (Thm. "Homotopy invariance of homology": deformation conserves nothing
-- but @H_0 = Z@).
cone :: [Simplex] -> [Simplex]
cone faces = closure (faces ++ map (apex :) faces ++ [[apex]])
  where apex = 1 + maximum (0 : concat faces)

-- | Build the (non-reduced) simplicial chain complex of an abstract simplicial
-- complex, presented by any list of simplices (need not be downward closed --
-- it is closed here).  The basis of @C_k@ is the sorted list of @k@-simplices,
-- and @d_k@ is the incidence matrix of the alternating-face boundary.
fromSimplicialComplex :: [Simplex] -> ChainComplex
fromSimplicialComplex faces0 =
  ChainComplex { dims = ds, boundaries = bnds }
  where
    faces :: [Simplex]
    faces = closure faces0

    byDim :: Int -> [Simplex]
    byDim d = sort [ s | s <- faces, length s == d + 1 ]

    maxDim :: Int
    maxDim = maximum (0 : [ length s - 1 | s <- faces ])

    cells :: [[Simplex]]
    cells = [ byDim d | d <- [0 .. maxDim] ]

    ds :: [Int]
    ds = map length cells

    bnds :: [Matrix]
    bnds = [ boundaryMatrix k | k <- [1 .. maxDim] ]

    -- d_k : C_k -> C_{k-1}: rows are (k-1)-simplices, columns are k-simplices.
    boundaryMatrix :: Int -> Matrix
    boundaryMatrix k =
      [ [ coeffOf faceS colS | colS <- cells !! k ]
      | faceS <- cells !! (k - 1) ]

    coeffOf :: Simplex -> Simplex -> Int
    coeffOf faceS colS =
      sum [ a | (a, t) <- boundarySimplex colS, t == faceS ]

-- ---------------------------------------------------------------------------
-- Concrete examples (Section "(Co)homology as conserved global information")
-- ---------------------------------------------------------------------------

-- | The circle @S^1@ as a CW complex with one 0-cell and one 1-cell; the 1-cell
-- is a loop so @d_1 = 0@.  Expected Betti: @(1,1)@.
circle :: ChainComplex
circle = ChainComplex
  { dims       = [1, 1]
  , boundaries = [ [[0]] ]        -- d_1 : C_1 -> C_0 is the 1x1 zero map
  }

-- | The 2-torus @T^2@ as the standard Delta-complex: one vertex, three edges
-- (a,b,c), two triangles, both with boundary @a + b - c@.  Then @d_1 = 0@ and
-- @rank d_2 = 1@.  Expected Betti: @(1,2,1)@.
torus :: ChainComplex
torus = ChainComplex
  { dims       = [1, 3, 2]
  , boundaries =
      [ [[0, 0, 0]]                    -- d_1 : C_1 (3) -> C_0 (1), zero
      , [ [ 1,  1]                     -- d_2 : C_2 (2) -> C_1 (3)
        , [ 1,  1]                     -- rows = edges a,b,c ; cols = triangles
        , [-1, -1] ]
      ]
  }

-- | The 2-sphere @S^2@ as a CW complex with one 0-cell and one 2-cell; the
-- attaching map is trivial so @d_2 = 0@ and there are no 1-cells.  Expected
-- Betti: @(1,0,1)@.
sphere2 :: ChainComplex
sphere2 = ChainComplex
  { dims       = [1, 0, 1]
  , boundaries =
      [ [[]]        -- d_1 : C_1 (0) -> C_0 (1) : one row, no columns (1x0)
      , []          -- d_2 : C_2 (1) -> C_1 (0), the zero map into the 0 group (0x1)
      ]
  }

-- | A single point.  Expected Betti: @(1)@.
pointSpace :: ChainComplex
pointSpace = ChainComplex { dims = [1], boundaries = [] }
