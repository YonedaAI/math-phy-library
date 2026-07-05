-- |
-- Module      : RepStack
-- Description : Representation entries, translations, and the composition of
--               entries with automatic status propagation.
--
-- Encodes Definition "representation entry" @E = (M, P, tau, sigma)@,
-- Definition "translation strength", and the composition of entries whose
-- composite status is computed by the /join/ of Status (the less-reliable
-- label; Theorem: status calculus, part 2).
module RepStack
  ( Translation(..)
  , candidateStatus
  , composeTranslation
    -- * Representation entries.
    --
    -- @RepEntry@ is exported /abstractly/: only its field selectors and the
    -- smart constructor 'mkRepEntry' are public, so every entry constructed
    -- outside this module is guaranteed 'wellFormedEntry' (its assigned status
    -- is never stronger than the translation's candidate).
  , RepEntry            -- abstract: constructor intentionally not exported
  , mathStruct, physRep, translation, status   -- field selectors
  , mkRepEntry
  , wellFormedEntry
  , identityEntry
  , composeEntry
  , composeEntryChecked
  , transportAlong
  , runTranslation
  ) where

import Status (Status(..), joinStatus, moreReliable)

-- | Graded translation witnesses, in decreasing strength
-- (Definition: translation strength).  The constructor records how strong a
-- witness the translation carries; 'candidateStatus' reads off the nominal
-- (candidate) epistemic label.
data Translation m p
  = FunctorialTranslation (m -> p)        -- ^ an actual functor; candidate S
  | NaturalTranslation    (m -> p)        -- ^ a natural transformation; candidate S\/H
  | InterpretiveRule      (m -> Maybe p)  -- ^ an analogy\/dictionary rule; candidate H
  | SpeculativeMap        (m -> Maybe p)  -- ^ a proposed, unconstructed (hence
                                          --   possibly partial) assignment; candidate P

-- | The nominal (candidate) status suggested by a translation's strength
-- (Definition: translation strength).  This is the /nominal mathematical/
-- strength; the actual entry status may be weaker (assigned by the author).
--
-- Note the paper lists a natural translation as candidate @S/H@: its strength
-- \"as mathematics\" is standard ('Std'), and the @H@ arises only when the
-- /physical reading/ is heuristic --- which is recorded not here but by the
-- author-assigned entry status (see 'mkRepEntry', which never lets the assigned
-- status be /stronger/ than this candidate).  We therefore take the nominal
-- candidate of a natural translation to be 'Std'.
candidateStatus :: Translation m p -> Status
candidateStatus (FunctorialTranslation _) = Std
candidateStatus (NaturalTranslation    _) = Std   -- nominal (mathematical) strength; S/H via assignment
candidateStatus (InterpretiveRule      _) = Heur
candidateStatus (SpeculativeMap        _) = Spec

-- | Apply a translation to a mathematical structure, if defined.  The two
-- \"standard\" (functorial, natural) translations are total; the interpretive
-- rule and the speculative map may be partial.
runTranslation :: Translation m p -> m -> Maybe p
runTranslation (FunctorialTranslation f) m = Just (f m)
runTranslation (NaturalTranslation    f) m = Just (f m)
runTranslation (InterpretiveRule      f) m = f m
runTranslation (SpeculativeMap        f) m = f m

-- | Compose two translations honestly, composing the underlying (possibly
-- partial) maps and degrading the /candidate/ strength to the strictly weaker
-- (less reliable) of the two legs.  The rule is the reliability weakest-link:
--
--   * a speculative leg (candidate @Spec@) dominates any other, so the composite
--     is speculative;
--   * otherwise an interpretive leg (candidate @Heur@) dominates the standard
--     legs, so the composite is interpretive;
--   * otherwise both legs are standard (functorial\/natural) and the composite is
--     standard (natural if either leg is natural, functorial if both are).
--
-- Consequently 'candidateStatus' of the composite equals
-- @'candidateStatus' t1 \`'max'\` 'candidateStatus' t2@ exactly: it is a monoid
-- homomorphism from (translations, composition) to the status join monoid.  In
-- particular the composite's candidate strength is /never stronger/ than either
-- factor (Definition: translation strength), so the composite entry may
-- legitimately carry any status at least as weak as this candidate.  The
-- underlying map is always the Kleisli composition of the two (partial) maps
-- @'runTranslation' t2 <=< 'runTranslation' t1@.
composeTranslation :: Translation b c -> Translation a b -> Translation a c
composeTranslation t2 t1 = case (t1, t2) of
  -- both legs standard and total: stay standard.
  (FunctorialTranslation f1, FunctorialTranslation f2) -> FunctorialTranslation (f2 . f1)
  (FunctorialTranslation f1, NaturalTranslation    f2) -> NaturalTranslation    (f2 . f1)
  (NaturalTranslation    f1, FunctorialTranslation f2) -> NaturalTranslation    (f2 . f1)
  (NaturalTranslation    f1, NaturalTranslation    f2) -> NaturalTranslation    (f2 . f1)
  -- an interpretive leg (and no speculative leg): composite is interpretive (Heur).
  (FunctorialTranslation f1, InterpretiveRule      g2) -> InterpretiveRule (g2 . f1)
  (NaturalTranslation    f1, InterpretiveRule      g2) -> InterpretiveRule (g2 . f1)
  (InterpretiveRule      g1, FunctorialTranslation f2) -> InterpretiveRule (fmap f2 . g1)
  (InterpretiveRule      g1, NaturalTranslation    f2) -> InterpretiveRule (fmap f2 . g1)
  (InterpretiveRule      g1, InterpretiveRule      g2) -> InterpretiveRule (\a -> g1 a >>= g2)
  -- any speculative leg dominates: composite is speculative (Spec, possibly partial).
  (FunctorialTranslation f1, SpeculativeMap        s2) -> SpeculativeMap (s2 . f1)
  (NaturalTranslation    f1, SpeculativeMap        s2) -> SpeculativeMap (s2 . f1)
  (InterpretiveRule      g1, SpeculativeMap        s2) -> SpeculativeMap (\a -> g1 a >>= s2)
  (SpeculativeMap        s1, FunctorialTranslation f2) -> SpeculativeMap (fmap f2 . s1)
  (SpeculativeMap        s1, NaturalTranslation    f2) -> SpeculativeMap (fmap f2 . s1)
  (SpeculativeMap        s1, InterpretiveRule      g2) -> SpeculativeMap (\a -> s1 a >>= g2)
  (SpeculativeMap        s1, SpeculativeMap        s2) -> SpeculativeMap (\a -> s1 a >>= s2)

-- | A representation entry @E = (M, P, tau, sigma)@ (Definition: representation
-- entry).  The @status@ is the /assigned/ epistemic label; per Definition
-- "translation strength" it may be /weaker/ (less reliable) than, but never
-- /stronger/ (more reliable) than, 'candidateStatus' of the translation.  The
-- type is exported /abstractly/ (only the field selectors and the smart
-- constructor 'mkRepEntry' are public); building an entry through 'mkRepEntry'
-- guarantees this invariant ('wellFormedEntry').
data RepEntry m p = RepEntry
  { mathStruct  :: m
  , physRep     :: p
  , translation :: Translation m p
  , status      :: Status
  }

-- | Well-formedness invariant of an entry (Definition: translation strength):
-- the assigned status is at least as weak as the translation's candidate
-- status, i.e. @candidateStatus tau `moreReliable` sigma@ (equivalently
-- @candidateStatus tau <= sigma@ in the reliability order).  An author may
-- weaken but not strengthen the nominal label.
wellFormedEntry :: RepEntry m p -> Bool
wellFormedEntry e = moreReliable (candidateStatus (translation e)) (status e)

-- | Smart constructor for a representation entry that enforces
-- 'wellFormedEntry' by /normalizing/ the requested status: the actual status is
-- @requested `joinStatus` candidateStatus tau@, so it can only ever be weakened
-- to meet the translation's candidate, never claim to be stronger than it.
mkRepEntry :: m -> p -> Translation m p -> Status -> RepEntry m p
mkRepEntry m p tau requested = RepEntry
  { mathStruct  = m
  , physRep     = p
  , translation = tau
  , status      = requested `joinStatus` candidateStatus tau
  }

-- | The identity entry on a structure: the trivial standard translation.
-- These are the units of entry composition.
identityEntry :: m -> RepEntry m m
identityEntry m = RepEntry
  { mathStruct  = m
  , physRep     = m
  , translation = FunctorialTranslation id
  , status      = Std
  }

-- | Compose two type-composable entries @E1 : a ~> b@ and @E2 : b ~> c@ into
-- @E2 . E1 : a ~> c@.  The composite status is @status E1 `joinStatus` status E2@,
-- i.e. the /join/ (the LESS reliable) of the two links (Theorem: status
-- calculus, part 2).
--
-- Type-composability (the shared middle type @b@) is witnessed by the types;
-- the translation of the composite is the honest 'composeTranslation' of the
-- two underlying (possibly partial) maps.  This preserves 'wellFormedEntry'
-- (the composite status is at least as weak as the composite candidate).  For
-- the paper's stronger /value/-composability premise @P1 = M2@ use
-- 'composeEntryChecked'.
composeEntry
  :: RepEntry b c    -- ^ the second (outer) entry @E2 : b ~> c@
  -> RepEntry a b    -- ^ the first  (inner) entry @E1 : a ~> b@
  -> RepEntry a c
composeEntry e2 e1 = RepEntry
  { mathStruct  = mathStruct e1
  , physRep     = physRep e2
  , translation = composeTranslation (translation e2) (translation e1)  -- honest composite
  , status      = status e1 `joinStatus` status e2
  }

-- | Compose entries only when they are /value/-composable in the sense of
-- Theorem "status calculus" part (2): the outer entry's source object equals
-- the inner entry's target, @mathStruct E2 == physRep E1@ (\"@P1 = M2@\").
-- Returns 'Nothing' when the middle objects do not match, and otherwise the
-- same composite as 'composeEntry'.
composeEntryChecked
  :: Eq b
  => RepEntry b c    -- ^ the second (outer) entry @E2 : b ~> c@
  -> RepEntry a b    -- ^ the first  (inner) entry @E1 : a ~> b@
  -> Maybe (RepEntry a c)
composeEntryChecked e2 e1
  | physRep e1 == mathStruct e2 = Just (composeEntry e2 e1)
  | otherwise                   = Nothing

-- | Transport an entry along an equivalence of the underlying mathematical
-- structure (Definition: representation library, closure operation 2).  The
-- status is unchanged: transport along a genuine equivalence preserves
-- reliability.
transportAlong :: (a -> a) -> RepEntry a p -> RepEntry a p
transportAlong g e = e { mathStruct = g (mathStruct e) }
