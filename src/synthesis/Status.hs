-- | Module      : Status
--   Part VII (Synthesis) of "A Math->Physics Representation Library":
--   "A Modular Representation Synthesis".
--
--   Encodes the /status calculus/ of Part I (synthesis Sec. "The status
--   calculus", eq. status ordering S <= H <= P).  The three epistemic labels
--
--     S  (standard)     -- a standard mathematics / mathematical-physics fact
--     H  (heuristic)    -- a strong but heuristic dictionary entry
--     P  (speculative)  -- a speculative ontological extension
--
--   carry the commutative idempotent monoid structure with unit @S@ and
--   product @max@ under @S <= H <= P@.  The synthesis theorem (PI/T3) states
--   that the composite of two representation entries has status
--   @max(s1, s2)@: /status cannot improve under composition; a chain of
--   translations is only as reliable as its weakest link/.
module Status
  ( -- * The three epistemic labels
    Status(..)
    -- * Composition of statuses (PI/T3)
  , composeStatus
  , worstOf
    -- * The @max@-monoid (unit S)
  , StatusMax(..)
  ) where

-- | The tripartite epistemic status labels of the library, ordered
--   @S <= H <= P@ ("standard is stronger than heuristic is stronger than
--   speculative").  The derived 'Ord' realizes exactly this ordering.
data Status
  = S -- ^ standard
  | H -- ^ heuristic
  | P -- ^ speculative
  deriving (Eq, Ord, Show, Enum, Bounded)

-- | Composition of statuses (synthesis PI/T3): the status of a composite
--   representation entry is the join @max@ of the factor statuses.  Status
--   therefore never improves under composition.
composeStatus :: Status -> Status -> Status
composeStatus = max

-- | The status of a whole /chain/ of translations: the worst (maximal) label
--   encountered.  Empty chains are perfectly standard, so the unit is 'S'.
worstOf :: [Status] -> Status
worstOf = foldr composeStatus S

-- | The status monoid @({S,H,P}, max, S)@ used by the status calculus: a
--   commutative, idempotent monoid.  Wrapping is needed so the 'Semigroup'
--   instance is the @max@-join rather than any other structure on 'Status'.
newtype StatusMax = StatusMax { getStatus :: Status }
  deriving (Eq, Ord, Show)

instance Semigroup StatusMax where
  StatusMax a <> StatusMax b = StatusMax (composeStatus a b)

instance Monoid StatusMax where
  mempty = StatusMax S
