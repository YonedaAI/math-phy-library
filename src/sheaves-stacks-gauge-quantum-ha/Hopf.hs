-- | Module      : Hopf
--   Part VI of "A Math->Physics Representation Library".
--
--   The Connes--Kreimer Hopf algebra of rooted trees (Theorem T4).  We
--   represent forests as multisets (lists) of rooted trees and implement:
--
--     * the coproduct  Delta(t) = t (x) 1 + 1 (x) t + sum_c P^c(t) (x) R^c(t)
--       over admissible cuts, and
--     * the antipode  S(t) = -t - sum_c S(P^c(t)) . R^c(t),
--
--   which computes the renormalization counterterm (BPHZ).  This is the same
--   formal coproduct/decomposition operation Delta used in Part II (Goncharov
--   coaction): the shared graded-connected-Hopf-algebra backbone.
--
--   Modeling note (planar vs. non-planar).  A 'RootedTree' stores its children as
--   an /ordered/ list and derives 'Eq'/'Ord' on that order, so trees are
--   effectively planar (ordered) rooted trees.  Forests, by contrast, are treated
--   as /commutative/ products: 'normalize' sorts each forest so that products are
--   order-independent.  The resulting object is a graded connected bialgebra --
--   the (planar-labelled) Connes--Kreimer Hopf algebra -- for which the antipode,
--   coassociativity, counit and both antipode axioms verified below all hold; the
--   usual non-planar Connes--Kreimer algebra is its quotient by child reordering
--   and shares every identity checked here.
module Hopf
  ( RootedTree(..)
  , Forest
  , nodes
  , coproduct
  , antipode
  , counitPrimitive
  , verifyAntipodeAxiom
  , verifyRightAntipodeAxiom
  , verifyCoassociativity
  ) where

import Data.List (sort)

-- | A rooted tree: a root carrying a list (forest) of subtrees.
--   'Node []' is the single-vertex tree (a leaf).
newtype RootedTree = Node [RootedTree] deriving (Eq, Ord, Show)

-- | A forest is a (commutative) product of rooted trees; we normalize by
--   sorting so that products are order-independent.
type Forest = [RootedTree]

-- | Number of vertices (the loop-number grading).
nodes :: RootedTree -> Int
nodes (Node ts) = 1 + sum (map nodes ts)

-- | Formal Z-linear combinations of forests, as an association list
--   [(coefficient, forest)], with like terms collected.
type Formal = [(Int, Forest)]

normalize :: Formal -> Formal
normalize = collect . map (\(c, f) -> (c, sort f))
  where
    collect xs =
      [ (c, f)
      | f <- distinct (map snd xs)
      , let c = sum [ c' | (c', f') <- xs, f' == f ]
      , c /= 0 ]
    distinct = foldr (\y acc -> if y `elem` acc then acc else y : acc) []

scaleF :: Int -> Formal -> Formal
scaleF k = normalize . map (\(c, f) -> (k * c, f))

plusF :: Formal -> Formal -> Formal
plusF a b = normalize (a ++ b)

-- | Multiply two forests (concatenation, since the algebra is the free
--   commutative algebra on trees) and lift to formal combinations.
timesForest :: Forest -> Forest -> Forest
timesForest = (++)

timesF :: Formal -> Formal -> Formal
timesF a b = normalize [ (c1 * c2, timesForest f1 f2)
                       | (c1, f1) <- a, (c2, f2) <- b ]

-- | Admissible cuts of a rooted tree.  An admissible cut removes a subset of
--   edges such that any path from the root to a leaf crosses at most one cut
--   edge; it splits the tree into the pruned forest P^c (the parts detached
--   from the root) and the trunk R^c (the part containing the root).
--
--   We enumerate cuts recursively.  For a node with children subtrees ts, each
--   child may either be (a) kept attached (recursing into its own admissible
--   cuts) or (b) fully cut off at its connecting edge (the whole child subtree
--   joins the pruned forest, with trunk contribution empty).
--   Returns the list of (prunedForest, trunkTree) for NON-trivial trunks,
--   i.e. the "sum_c" part excluding the full and empty cuts.
admissibleCuts :: RootedTree -> [(Forest, RootedTree)]
admissibleCuts t0 =
  -- Keep only genuine cuts: the empty-pruned entry is the "no cut" option
  -- (trunk = whole tree) and is excluded here (it is the t (x) 1 term).  The
  -- total cut (whole tree pruned, empty trunk) never appears in allCuts, since
  -- allCuts always retains the root; it is the 1 (x) t term.
  [ (pruned, trunk) | (pruned, trunk) <- allCuts t0, not (null pruned) ]
  where
    -- allCuts returns every (prunedForest, trunk) INCLUDING the no-cut option
    -- (empty pruned forest, whole tree) but EXCLUDING the total cut (whole tree
    -- pruned, empty trunk), which is handled by the 1 (x) t term separately.
    allCuts :: RootedTree -> [(Forest, RootedTree)]
    allCuts (Node cs) =
      [ (concat prunedParts, Node trunks)
      | choices <- sequence (map childChoices cs)
      , let prunedParts = map fst choices
            trunks      = concatMap snd choices ]
      where
        -- For a child subtree, either cut it off entirely (prune whole child,
        -- contribute no trunk subtree) or keep its root edge and recurse.
        childChoices :: RootedTree -> [(Forest, [RootedTree])]
        childChoices child =
          ([child], []) :                        -- cut this child's edge
          [ (pruned, [trunk])                     -- keep edge, recurse
          | (pruned, trunk) <- allCuts child ]

-- | Coproduct  Delta(t) = t (x) 1 + 1 (x) t + sum_c P^c (x) R^c.
--   Returned as a list of (leftForest, rightForest) tensor terms.
coproduct :: RootedTree -> [(Forest, Forest)]
coproduct t =
  ([t], []) :                                  -- t (x) 1
  ([], [t]) :                                  -- 1 (x) t
  [ (pruned, [trunk]) | (pruned, trunk) <- admissibleCuts t ]

-- | Antipode, by the recursion  S(t) = -t - sum_c S(P^c) . R^c.
--   Returns a formal Z-linear combination of forests.
antipode :: RootedTree -> Formal
antipode t =
  plusF (scaleF (-1) [(1, [t])])
        (scaleF (-1) (foldr plusF []
           [ timesF (antipodeForest pruned) [(1, [trunk])]
           | (pruned, trunk) <- admissibleCuts t ]))

-- | Antipode extended multiplicatively to forests: S(t1 * t2) = S(t1) * S(t2),
--   S(empty) = 1.
antipodeForest :: Forest -> Formal
antipodeForest []       = [(1, [])]           -- S(1) = 1
antipodeForest (t : ts) = timesF (antipode t) (antipodeForest ts)

-- | A tree is primitive iff its reduced coproduct vanishes, i.e. Delta(t)
--   only has the two trivial terms t (x) 1 and 1 (x) t.  The single-vertex
--   tree is primitive (an "irreducible contribution", status S/H).
counitPrimitive :: RootedTree -> Bool
counitPrimitive t = null (admissibleCuts t)

-- | Hopf-algebra (left) antipode axiom check:
--   m . (S (x) id) . Delta (t) = eps(t) . 1.
--   For any tree of positive grading (eps(t) = 0) the left side must vanish.
--   This is a machine-checked correctness witness for 'antipode' and
--   'coproduct' together (Theorem T4).
verifyAntipodeAxiom :: RootedTree -> Bool
verifyAntipodeAxiom t =
  null (foldr plusF []
          [ timesF (antipodeForest leftF) [(1, rightF)]
          | (leftF, rightF) <- coproduct t ])

-- | Hopf-algebra /right/ antipode axiom check:
--   m . (id (x) S) . Delta (t) = eps(t) . 1.
--   The mirror of 'verifyAntipodeAxiom'; both must hold for a genuine Hopf
--   algebra, so checking the two independently strengthens the T4 witness.
verifyRightAntipodeAxiom :: RootedTree -> Bool
verifyRightAntipodeAxiom t =
  null (foldr plusF []
          [ timesF [(1, leftF)] (antipodeForest rightF)
          | (leftF, rightF) <- coproduct t ])

-- | Coproduct extended multiplicatively to a forest:
--   Delta(t1 * ... * tk) = Delta(t1) * ... * Delta(tk) in H (x) H, with the
--   empty forest (the unit) mapping to 1 (x) 1.  Returned as tensor terms
--   @(leftForest, rightForest)@.
coproductForest :: Forest -> [(Forest, Forest)]
coproductForest = foldr step [([], [])]
  where
    step t acc =
      [ (timesForest l1 l2, timesForest r1 r2)
      | (l1, r1) <- coproduct t
      , (l2, r2) <- acc ]

-- | Coassociativity witness for the bialgebra axiom:
--   (Delta (x) id) . Delta  =  (id (x) Delta) . Delta   as maps into H^{(x)3}.
--   Each side is expanded to a list of triples of forests; since every
--   coproduct coefficient is @+1@, comparing the sorted lists (with
--   multiplicity, and each forest canonicalized by 'sort') compares the two
--   elements of H (x) H (x) H exactly.  Returns 'True' iff they agree.
verifyCoassociativity :: RootedTree -> Bool
verifyCoassociativity t = normalizeTriples lhs == normalizeTriples rhs
  where
    lhs = [ (a1, a2, r) | (a, r) <- coproduct t, (a1, a2) <- coproductForest a ]
    rhs = [ (l, b1, b2) | (l, b) <- coproduct t, (b1, b2) <- coproductForest b ]
    normalizeTriples =
      sort . map (\(a, b, c) -> (sort a, sort b, sort c))
