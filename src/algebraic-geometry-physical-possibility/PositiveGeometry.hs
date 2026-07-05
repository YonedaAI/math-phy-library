-- | Module      : PositiveGeometry
--   Description : Positive geometries and their recursive residue trees,
--                 encoding Definition 7.1, Definition 7.4, and Theorem 8.5(1)
--                 of Part III: the residue along a facet is the canonical form
--                 of that facet, and iterating produces a coalgebra-like
--                 decomposition tree.
--
--   We give a symbolic model of a canonical form (a product of simple poles)
--   sufficient to compute residues and build the residue tree. Each boundary
--   stratum is tagged with the facet it descends through, and the model
--   satisfies the residue axiom on interior facets by construction
--   (@stratum form = Res_facet parent form@); the recursion terminates at
--   0-dimensional strata (vertices), whose canonical form is a bare number
--   (a form with no poles), exactly as in the interval/simplex examples of
--   Section 8.
module PositiveGeometry
  ( DiffForm(..)
  , PositiveGeometry(..)
  , Facet(..)
  , Tree(..)
  , residueAt
  , residueTree
  , treeSize
  , treeLeaves
  , isPoint
  , fromForm
  , residueAxiomHolds
  , allLeavesArePoints
  , interval
  , simplex
  ) where

import Data.List (nub)

-- | A toy canonical form: a rational top-form recorded by the list of its
--   boundary "poles" (labels of the facets it has simple poles along) and an
--   overall sign/coefficient. The canonical form of a 0-dimensional geometry
--   (a point/vertex) is a number, recorded as a form with no poles.
data DiffForm = DiffForm
  { poles       :: [String]   -- facet labels along which the form has simple poles
  , coefficient :: Rational
  } deriving (Eq)

instance Show DiffForm where
  show (DiffForm [] c) = show c
  show (DiffForm ps c) = show c ++ " * dlog[" ++ unwords ps ++ "]"

-- | A labelled boundary of a positive geometry: the facet label together with
--   the boundary stratum (itself a positive geometry).
data Facet = Facet
  { facetLabel :: String
  , stratum    :: PositiveGeometry
  }

-- | A positive geometry: a canonical form together with its boundary strata,
--   each tagged by the facet it is the residue along (the recursion of
--   Definition 7.1/7.4).
data PositiveGeometry = PositiveGeometry
  { label         :: String
  , canonicalForm :: DiffForm
  , boundaries    :: [Facet]
  }

-- | A rooted tree, the shape of a coalgebraic decomposition.
data Tree a = Node a [Tree a]

instance (Show a) => Show (Tree a) where
  show = go 0
    where
      go d (Node a kids) =
        replicate (2 * d) ' ' ++ show a ++ "\n"
          ++ concatMap (go (d + 1)) kids

-- | The residue of the canonical form along a named facet: drop that pole.
--   Models Res_{facet} Omega = Omega(facet) (the residue axiom, Definition 7.1),
--   returning the canonical form of the boundary stratum.
residueAt :: String -> DiffForm -> DiffForm
residueAt facet (DiffForm ps c) = DiffForm (filter (/= facet) ps) c

-- | A 0-dimensional stratum (a vertex/point): no boundary facets remain.
isPoint :: PositiveGeometry -> Bool
isPoint = null . boundaries

-- | The residue tree (Definition 7.4 / Theorem 8.5(1)): root decorated by the
--   canonical form, children the residue trees of the boundary strata.
residueTree :: PositiveGeometry -> Tree DiffForm
residueTree pg =
  Node (canonicalForm pg) (map (residueTree . stratum) (boundaries pg))

-- | Number of nodes in a tree (size of the decomposition).
treeSize :: Tree a -> Int
treeSize (Node _ kids) = 1 + sum (map treeSize kids)

-- | Leaves of a tree (the 0-dimensional strata: the "primitive" pieces).
treeLeaves :: Tree a -> [a]
treeLeaves (Node a []) = [a]
treeLeaves (Node _ kids) = concatMap treeLeaves kids

-- | Build the positive geometry whose canonical form is the given form by
--   iterated residues: each remaining facet (pole) is a labelled boundary whose
--   stratum is the residue of the form along that facet, recursing until the
--   pole set is empty (a 0-form / vertex). By construction, the residue axiom
--   @stratum form = Res_facet parent form@ holds at EVERY edge (see
--   'residueAxiomHolds'), and every leaf is a numeric 0-form (see
--   'allLeavesArePoints'). The leaves are the residues along complete facet
--   flags, so an @n@-simplex has @(n+1)!@ of them.
fromForm :: String -> DiffForm -> PositiveGeometry
fromForm name (DiffForm ps0 c) = PositiveGeometry
  { label         = name
  , canonicalForm = df
  , boundaries    =
      [ Facet f (fromForm (name ++ "|" ++ f) (residueAt f df)) | f <- ps ]
  }
  where
    ps = nub ps0                     -- simple poles: one facet per distinct label
    df = DiffForm ps c

-- | The residue axiom (Theorem 8.5(1)) as a checkable invariant, tested at
--   EVERY edge (including terminal edges to vertices): each boundary stratum's
--   canonical form equals the residue of its parent's canonical form along the
--   labelling facet.
residueAxiomHolds :: PositiveGeometry -> Bool
residueAxiomHolds pg =
     all edgeOK (boundaries pg)
  && all (residueAxiomHolds . stratum) (boundaries pg)
  where
    edgeOK b =
      canonicalForm (stratum b) == residueAt (facetLabel b) (canonicalForm pg)

-- | Every leaf (vertex) of the residue tree is a genuine 0-form: a number with
--   no remaining poles (Theorem 8.5(1): the recursion terminates at points).
allLeavesArePoints :: PositiveGeometry -> Bool
allLeavesArePoints = all (null . poles) . treeLeaves . residueTree

-- | The interval [a,b] in P^1 (Example 7.2): a 1-form with simple poles at the
--   two endpoints @a,b@. Its iterated-residue tree terminates at the two numeric
--   vertices (residues along the flags @a<b@ and @b<a@).
interval :: PositiveGeometry
interval = fromForm "[a,b]" (DiffForm ["a", "b"] 1)

-- | The standard n-simplex (Example 7.2): canonical form with simple poles
--   along its (n+1) facets. Its iterated-residue tree (built by 'fromForm')
--   satisfies the residue axiom at every edge and terminates at numeric
--   vertices; there are @(n+1)!@ leaves (one per complete facet flag).
simplex :: Int -> PositiveGeometry
simplex n = fromForm ("Delta^" ++ show n) (DiffForm [ "H" ++ show i | i <- [0 .. n] ] 1)
