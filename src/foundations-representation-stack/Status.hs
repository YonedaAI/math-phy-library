-- |
-- Module      : Status
-- Description : The epistemic status calculus S < H < P (Theorem: status calculus).
--
-- Encodes the S/H/P status system of the representation-stack foundations paper
-- as an ordered, commutative, idempotent monoid.  The monoid operation @join@
-- returns the LESS reliable of two labels (their supremum/join in the
-- reliability order Std < Heur < Spec); the unit is the bottom element 'Std'.
-- Composing translations therefore computes the composite status automatically,
-- which is exactly Theorem "status calculus" part (2) and Corollary
-- "reliability of a pipeline".
module Status
  ( Status(..)
  , rank
  , joinStatus
  , moreReliable
  , joinAll
  ) where

-- | Epistemic status labels, ordered by reliability: @Std < Heur < Spec@.
--
--   * 'Std'  — standard use in mathematics or mathematical physics (label S).
--   * 'Heur' — strong heuristic representation-dictionary entry (label H).
--   * 'Spec' — speculative philosophical ontology (label P).
--
-- The declaration order of the constructors is the single source of truth for
-- the reliability order: the derived 'Ord' (and 'Enum') instances realize
-- @Std < Heur < Spec@, and 'rank' below (@= fromEnum@) is the explicit numeric
-- witness of exactly that order, so the two never drift apart.
data Status = Std | Heur | Spec
  deriving (Eq, Ord, Show, Enum, Bounded)

-- | Numeric reliability rank; smaller means more reliable.  This is the
-- explicit case @Std -> 0, Heur -> 1, Spec -> 2@ (via 'fromEnum'), pinning down
-- the reliability order used by 'joinStatus' and 'moreReliable'.
rank :: Status -> Int
rank = fromEnum

-- | The status monoid join: the LESS reliable of two labels.
--
-- This is @max@ (supremum / join) under the reliability order
-- @Std < Heur < Spec@.  It is associative, commutative, idempotent, and has the
-- bottom element 'Std' as its unit.
joinStatus :: Status -> Status -> Status
joinStatus = max

-- | Reliability comparison: @a `moreReliable` b@ iff @a@ is at least as
-- reliable as @b@ (i.e. @a <= b@ in the reliability order).
moreReliable :: Status -> Status -> Bool
moreReliable = (<=)

-- | Fold the join over a chain of statuses.  The status of a chain of
-- translations is the join of the links (Corollary: reliability of a pipeline).
-- An empty chain is perfectly reliable ('Std', the unit).
joinAll :: [Status] -> Status
joinAll = foldr joinStatus Std

-- The 'Semigroup'/'Monoid' instances make @(<>)@ compute composite status.
instance Semigroup Status where
  (<>) = joinStatus

instance Monoid Status where
  mempty = Std
