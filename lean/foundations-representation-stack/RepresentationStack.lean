/-
  Foundations: The Representation Stack and the Realization Pipeline
  Part I of "A Math -> Physics Representation Library".

  Best-effort idiomatic Lean 4 sketch of the CORE types, structures, and
  definition-signatures of the representation-stack formalism.  This file is a
  specification artifact: it fixes the intended formal statements for later
  mechanization.  It is NOT build-gated and need not fully elaborate against a
  particular Mathlib revision; the categorical/descent content (pseudofunctors,
  Grothendieck topologies, descent data) is deferred to Parts V and VI.
-/

namespace RepresentationStack

/-! ## The epistemic status calculus (Theorem: status calculus) -/

/-- Epistemic status labels.  The derived `Ord` instance orders them by
    declaration order, `std < heur < spec`, i.e. increasing UNreliability.
    * `std`  — standard mathematics / mathematical physics (label S)
    * `heur` — strong heuristic dictionary entry (label H)
    * `spec` — speculative philosophical ontology (label P) -/
inductive Status where
  | std | heur | spec
  deriving DecidableEq, Repr, Ord

namespace Status

/-- The status-monoid join: the LESS reliable of two labels, i.e. their join
    (supremum / greater) in the derived order `std < heur < spec`.  This is the
    operation `∨` of the status calculus; its unit is the bottom element `std`. -/
def join (a b : Status) : Status :=
  match compare a b with
  | .lt => b
  | _   => a

/-- `std` is the unit (bottom) of `join`: `join std a = a`. -/
theorem join_std_left (a : Status) : join Status.std a = a := by
  cases a <;> decide

/-- `join` is idempotent. -/
theorem join_idem (a : Status) : join a a = a := by
  cases a <;> decide

end Status

/-! ## Domains, structures, physical targets -/

/-- A physical target category is abstracted here as a bare type of physical
    representation objects (state spaces, observable algebras, code spaces, …). -/
abbrev PhysTarget := Type

/-! ## Translations (Definition: translation strength) -/

/-- Graded translation witnesses from a mathematical structure type `M` to a
    physical representation type `P`, in decreasing strength. -/
inductive Translation (M P : Type) where
  | functorial   : (M → P) → Translation M P        -- candidate S
  | natural      : (M → P) → Translation M P        -- candidate S/H
  | interpretive : (M → Option P) → Translation M P -- candidate H
  | speculative  : (M → P) → Translation M P        -- candidate P

/-- The nominal (candidate) status suggested by a translation's strength. -/
def Translation.candidateStatus {M P : Type} : Translation M P → Status
  | .functorial   _ => .std
  | .natural      _ => .std
  | .interpretive _ => .heur
  | .speculative  _ => .spec

/-- Compose two translations honestly: compose the underlying (possibly partial)
    maps and degrade the strength to the weaker of the two.  Interpretive
    partiality propagates; a speculative leg makes the total composite
    speculative.  This keeps the composite translation's candidate strength no
    stronger than either factor, so a composite entry may legitimately carry any
    status at least as weak as the composite's candidate (Definition:
    translation strength). -/
def Translation.comp {A B C : Type}
    (t2 : Translation B C) (t1 : Translation A B) : Translation A C :=
  match t1, t2 with
  | .functorial f1, .functorial f2 => .functorial (fun a => f2 (f1 a))
  | .functorial f1, .natural    f2 => .natural    (fun a => f2 (f1 a))
  | .functorial f1, .speculative f2 => .speculative (fun a => f2 (f1 a))
  | .natural    f1, .functorial f2 => .natural    (fun a => f2 (f1 a))
  | .natural    f1, .natural    f2 => .natural    (fun a => f2 (f1 a))
  | .natural    f1, .speculative f2 => .speculative (fun a => f2 (f1 a))
  | .speculative f1, .functorial f2 => .speculative (fun a => f2 (f1 a))
  | .speculative f1, .natural    f2 => .speculative (fun a => f2 (f1 a))
  | .speculative f1, .speculative f2 => .speculative (fun a => f2 (f1 a))
  -- any interpretive leg makes the composite partial (interpretive):
  | .interpretive g1, .functorial f2 => .interpretive (fun a => (g1 a).map f2)
  | .interpretive g1, .natural    f2 => .interpretive (fun a => (g1 a).map f2)
  | .interpretive g1, .speculative f2 => .interpretive (fun a => (g1 a).map f2)
  | .interpretive g1, .interpretive g2 => .interpretive (fun a => (g1 a).bind g2)
  | .functorial f1, .interpretive g2 => .interpretive (fun a => g2 (f1 a))
  | .natural    f1, .interpretive g2 => .interpretive (fun a => g2 (f1 a))
  | .speculative f1, .interpretive g2 => .interpretive (fun a => g2 (f1 a))

/-! ## Representation entries (Definition: representation entry) -/

/-- A representation entry `E = (M, P, τ, σ)`. -/
structure RepEntry (M P : Type) where
  mathStruct  : M
  physRep     : P
  translation : Translation M P
  status      : Status

/-- The identity entry on a structure: the trivial standard translation. -/
def RepEntry.id {M : Type} (m : M) : RepEntry M M :=
  { mathStruct  := m
  , physRep     := m
  , translation := .functorial (fun x => x)
  , status      := .std }

/-- Compose two composable entries `e1 : A ~> B` and `e2 : B ~> C` into
    `e2 ∘ e1 : A ~> C`.  The composite status is `Status.join e1.status
    e2.status`, i.e. the LESS reliable of the two links (Theorem: status
    calculus, part 2), mirroring the Haskell `composeEntry`. -/
def RepEntry.comp {A B C : Type}
    (e2 : RepEntry B C) (e1 : RepEntry A B) : RepEntry A C :=
  { mathStruct  := e1.mathStruct
  , physRep     := e2.physRep
  , translation := Translation.comp e2.translation e1.translation  -- honest composite
  , status      := Status.join e1.status e2.status }

/-- The composite of two standard entries is standard: `join std std = std`. -/
theorem RepEntry.comp_std {A B C : Type}
    (e2 : RepEntry B C) (e1 : RepEntry A B)
    (h1 : e1.status = Status.std) (h2 : e2.status = Status.std) :
    (RepEntry.comp e2 e1).status = Status.std := by
  have hstat : (RepEntry.comp e2 e1).status
      = Status.join e1.status e2.status := rfl
  rw [hstat, h1, h2]
  decide

/-! ## The realization pipeline (Definition: realization pipeline) -/

/-- Realization channels indexed by `α`. -/
inductive Channel where
  | betti | deRham | hodge | etale | pAdic | quantum
  | thermodynamic | computational | experimental | operational
  deriving DecidableEq, Repr

/-- A single functorial stage: a map together with the status at which it is
    actually constructed. -/
structure Stage (A B : Type) where
  map        : A → B
  stageStat  : Status

/-- The realization pipeline over a channel: `Obs ∘ Real_α ∘ Φ`. -/
structure Pipeline (M I R O : Type) where
  channel : Channel
  phi     : Stage M I     -- Φ : abstract-information functor
  realA   : Stage I R     -- Real_α : realization channel
  obs     : Stage R O     -- Obs : observable extraction

/-- Run the pipeline: `Obs_α(m) = Obs (Real_α (Φ m))`. -/
def Pipeline.run {M I R O : Type} (P : Pipeline M I R O) : M → O :=
  fun m => P.obs.map (P.realA.map (P.phi.map m))

/-- The status of a pipeline is the join of its three stage statuses
    (Corollary: reliability of a pipeline). -/
def Pipeline.status {M I R O : Type} (P : Pipeline M I R O) : Status :=
  Status.join (Status.join P.phi.stageStat P.realA.stageStat) P.obs.stageStat

/-! ## The representation prestack (Definition: representation prestack)

    A full formalization requires pseudofunctors `Domᵒᵖ → Gpd` and a
    Grothendieck topology; those live in Parts V and VI.  Here we record the
    signature: a domain-indexed assignment of a groupoid of entries together
    with restriction along refinements. -/

/-- Signature of a representation prestack over a type `Dom` of domains and a
    physical target type `P`.  `Rep d` is the type of entries native to `d`;
    `restrict` is the restriction functor along a refinement `e → d`
    (refinements modelled abstractly as a relation `Ref`). -/
structure RepresentationPrestack (Dom : Type) (Ref : Dom → Dom → Type)
    (M P : Type) where
  Rep      : Dom → Type
  entryOf  : ∀ d, Rep d → RepEntry M P
  restrict : ∀ {e d : Dom}, Ref e d → Rep d → Rep e

/-- The stack condition (Definition: representation stack) is the proposition
    that restriction satisfies descent for a coverage.  We record it as an
    opaque predicate to be supplied by Part VI's descent theory. -/
def IsRepresentationStack
    {Dom : Type} {Ref : Dom → Dom → Type} {M P : Type}
    (_prestack : RepresentationPrestack Dom Ref M P)
    (_satisfiesDescent : Prop) : Prop :=
  _satisfiesDescent

end RepresentationStack
