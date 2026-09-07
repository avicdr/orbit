# Orbit Architecture

## Targets

`OrbitShared` is a local Swift package containing all domain types, SwiftData models, persistence construction, platform-neutral services, and design-system primitives. The Xcode targets compile that one physical shared source tree as target membership, while the package provides an independent shared-module test boundary. `Orbit-iOS`, `Orbit-macOS`, and `Orbit-watchOS` are deliberately small native SwiftUI application shells.

The platform targets have distinct future responsibilities: iPhone is for planning and context, Mac is the command center, and Watch is for short execution flows. No business rules belong in SwiftUI views.

## Domain model

The persistent hierarchy is `Orbit → Goal → Project → OrbitTask → FocusSession`. An `OrbitTask` may also retain direct Goal and Orbit links, allowing meaningful assignment while a project is absent. `DailyState` records a day’s energy and manually available time. `TaskContext` stores extensible named contexts. `CalendarAvailability` is an ephemeral abstraction; EventKit event data will not be duplicated.

Raw persisted values back public, strongly typed status, priority, energy, recurrence, context, and difficulty properties. This keeps the SwiftData schema stable while keeping domain call sites type safe.

## Persistence and migration

`OrbitModelContainer` owns the explicit schema and produces a local SwiftData container. `OrbitRepository` is the mutation boundary for the hierarchy; it implements archive and conservative deletion behavior rather than letting UI code delete models directly. Model identifiers are UUIDs and `DailyState.date` is unique.

The initial persisted schema is `OrbitSchemaV1`. `OrbitSchemaV2` adds the standalone `TaskSchedule` model and declares a lightweight V1→V2 migration. A placement references its task UUID rather than changing the original task schema, so it can be migrated additively and removed safely with its task. Future persisted changes must add a versioned schema and a declared `SchemaMigrationPlan` stage; they must not silently mutate V1. CloudKit remains deliberately disabled until the sync milestone.

Deleting an Orbit unassigns work. Deleting a Goal retains its projects and tasks without the goal. Deleting a Project retains its tasks without the project. Deleting a Task cascades only to its Focus Sessions and removes it from task dependencies. `OrbitDevelopmentData` is explicit development/test data and is never automatically seeded in production.

When a task is assigned to a Project, `OrbitRepository` treats that Project as the hierarchy authority: the task inherits the Project’s Goal and Orbit. This prevents contradictory paths such as a task placed in a Learning project but associated with a Personal goal. Completion and reopening timestamps are also repository-owned transitions.

`OrbitRepository.capture` is the dedicated Inbox entry point. It persists only a title and the `.inbox` state. Organizing a task is an ordinary explicit task update; archiving changes it to `.cancelled`, while deletion uses the existing relationship-safe deletion path.

## Life timeline

`TaskSchedule` is an additive, persisted placement with a start and end date, separate from an `OrbitTask` due date. `TimelineEngine` is pure planning math: it composes scheduled tasks and calendar commitments, produces free windows, detects existing overlap, and evaluates a move proposal. A proposal with any overlap requires confirmation. The macOS surface performs drag/drop and editor interactions, while `OrbitRepository.schedule` and `unschedule` are the only persistence mutations. Orbit never automatically shifts, resizes, or deletes affected work.

## Time intelligence

`TimeEngine` is a pure, deterministic domain service. It receives a working window, optional manual capacity, calendar commitment blocks, scheduled task blocks, and unscheduled planned minutes; it returns available, committed, planned, free, overloaded minutes, and free windows. It merges overlapping commitments before calculating totals. `DailyState.availableMinutes` is the offline-first manual capacity source. EventKit will later adapt external events into `TimeBlock` values without changing the engine or requiring Calendar access for core behavior.

`EnergyMatcher` is another pure domain service. It accepts only an explicitly stored `DailyState.energyLevel` and a task’s energy requirement, returning `.match`, `.mismatch`, or `.unknown`. `OrbitRepository.updateDailyEnergy` persists the check-in without overwriting manual availability.

## Recommendations

`RecommendationEngine` is a pure local service operating on immutable `RecommendationTask` values and an explicit `RecommendationContext`. Fixed score components are priority (0–32), urgency (0–24), Orbit weight (0–12), context (0–12), energy (0–12), time fit (0–10), historical momentum (0–5), minus friction. Scores are normalized to 0–100 and include human-readable reasons. `RecommendationInputBuilder` adapts persisted tasks at the edge; no SwiftUI view or remote service participates in scoring.

## Context engine

`ContextEngine` converts explicit local inputs into an immutable `ContextSnapshot`: time, active context, available duration, energy, calendar state, current device, and location authorization state. It applies the most constrained explicit duration when both a manual window and calendar free window exist. It never requests a permission, reads sensors, infers a location, or stores coordinates. `ContextPreferenceStore` retains only the user’s deliberate manual label (such as Home or Campus) in local preferences. EventKit and optional one-shot location providers will remain adapters at the platform edge, so denied or unavailable permissions simply yield unknown context rather than fabricated data.

## Privacy

All foundation data is local. There are no network dependencies, analytics SDKs, AI APIs, calendar reads, location reads, or background tracking. Manual context labels are the only context data persisted outside SwiftData, and no coordinates or movement history are stored. Future EventKit and one-shot location capabilities must be permission-gated and degrade gracefully.

## Testing

The Swift Testing target tests the shared domain independently of any app UI. Persistence, relationship, and migration tests begin in Milestone 1 when CRUD behavior is introduced.
