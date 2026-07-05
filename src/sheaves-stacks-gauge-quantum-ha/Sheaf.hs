{-# LANGUAGE ScopedTypeVariables #-}

-- | Module      : Sheaf
--   Part VI of "A Math->Physics Representation Library".
--
--   Presheaves and sheaves over a finite site.  A presheaf assigns data to
--   regions and provides restriction maps; a sheaf additionally satisfies the
--   descent (gluing) condition: compatible local sections glue to a unique
--   global section (Definition, paper Section 3).
--
--   Physical reading (status S): presheaf = local observable assignment;
--   sheaf = physical fields reconstructed from compatible local measurements;
--   the gluing check = descent = coordinate-independent physics.
module Sheaf
  ( Opens
  , Cover(..)
  , Presheaf(..)
  , wellFormedFamily
  , compatible
  , isSeparated
  , glues
  , isSheafFor
  , constantPresheaf
  ) where

import Data.List (nub)

-- | Opens of the site are represented by their (finite) index sets of points;
--   restriction is intersection.  This is the topological site of
--   Example (topological site) in the paper.
type Opens = [Int]

-- | A covering family of an open @u@: a list of opens whose union is @u@.
newtype Cover = Cover { pieces :: [Opens] } deriving (Eq, Show)

-- | A presheaf valued in sets: a section assignment plus a restriction map
--   @restrict small big s@ that restricts a section over @big@ to @small@.
data Presheaf a = Presheaf
  { sections :: Opens -> [a]              -- ^ admissible sections over an open
  , restrict :: Opens -> Opens -> a -> a  -- ^ restrict from big to small
  }

-- | Union of the pieces of a cover.
coverUnion :: Cover -> Opens
coverUnion = nub . concat . pieces

-- | Pairwise overlaps U_i \cap U_j of a cover.
overlaps :: Cover -> [(Opens, Opens)]
overlaps (Cover us) =
  [ (ui, uj) | (i, ui) <- zip [0 :: Int ..] us
             , (j, uj) <- zip [0 :: Int ..] us
             , i < j ]

intersect' :: Opens -> Opens -> Opens
intersect' a b = [ x | x <- a, x `elem` b ]

-- | Separatedness: two global sections that agree on every piece of a cover
--   are equal.  Checked over a finite candidate set of sections.
isSeparated :: forall a. Eq a => Presheaf a -> Cover -> Bool
isSeparated pf cov =
  let u  = coverUnion cov
      gs = sections pf u
      agree s t = all (\p -> restrict pf p u s == restrict pf p u t)
                      (pieces cov)
  in and [ s == t | s <- gs, t <- gs, agree s t ]

-- | A section family is /well formed/ for a cover when it provides exactly one
--   local section per piece of the cover.  Ill-formed families (too few or too
--   many sections) are rejected outright rather than silently truncated by
--   'zipWith', which would make the descent check unsound.
wellFormedFamily :: Cover -> [a] -> Bool
wellFormedFamily cov locs = length locs == length (pieces cov)

-- | A family of local sections is /compatible/ when (i) it is well formed,
--   (ii) each local value is an /admissible/ section over its piece (a member of
--   @sections pf@ on that piece), and (iii) the two restrictions agree on every
--   overlap.  The well-formedness guard prevents a wrong-length family from
--   zipping short against the overlaps; the admissibility guard prevents
--   out-of-domain junk values (e.g. a value not in the presheaf's section set)
--   from being counted as local data.
compatible :: Eq a => Presheaf a -> Cover -> [a] -> Bool
compatible pf cov locs =
  wellFormedFamily cov locs &&
  and (zipWith admissible (pieces cov) locs) &&
  and [ restrict pf (intersect' ui uj) ui si
          == restrict pf (intersect' ui uj) uj sj
      | ((ui, uj), (si, sj)) <- zip (overlaps cov) (pairs locs) ]
  where
    admissible piece s = s `elem` sections pf piece
    pairs xs = [ (xs !! i, xs !! j)
               | i <- [0 .. length xs - 1]
               , j <- [i + 1 .. length xs - 1] ]

-- | Gluing: every compatible local family descends to some global section.
--   Only well-formed compatible families are considered; because 'compatible'
--   already enforces well-formedness, the inner 'zipWith' now always ranges over
--   matching lengths.
glues :: Eq a => Presheaf a -> Cover -> [[a]] -> Bool
glues pf cov localFamilies =
  all tryGlue (filter (compatible pf cov) localFamilies)
  where
    u = coverUnion cov
    tryGlue locs =
      wellFormedFamily cov locs &&
      any (\g -> and (zipWith (\p s -> restrict pf p u g == s)
                              (pieces cov) locs))
          (sections pf u)

-- | Sheaf condition for a given cover: separated AND every compatible family
--   glues.  (Equalizer diagram of the paper, Definition (Sheaf).)
isSheafFor :: Eq a => Presheaf a -> Cover -> [[a]] -> Bool
isSheafFor pf cov localFamilies =
  isSeparated pf cov && glues pf cov localFamilies

-- | The constant presheaf on a value type; sections are constant functions,
--   trivially a sheaf on a connected site.
constantPresheaf :: [a] -> Presheaf a
constantPresheaf vals = Presheaf
  { sections  = const vals
  , restrict  = \_ _ s -> s
  }
