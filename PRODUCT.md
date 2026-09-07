# Orbit Product Principles

Orbit is a Personal Context OS—not a conventional task manager. Its eventual question is: **given everything happening in my life, what deserves my attention right now?**

Its recommendations will remain local, deterministic, explainable, and testable. It will combine user-owned work hierarchy, available time, energy, context, and actual history without sending personal data to remote AI inference services.

## Platform roles

- **iPhone:** planning, context, capture, and today’s attention.
- **Mac:** the detailed planning and review command center.
- **Apple Watch:** fast execution, focus, completion, and brief check-ins.

Each platform stays native to its role: iPhone collects planning context, Mac supports detailed planning, and Watch remains concise during execution.

## Orbit management

An Orbit is a user-defined life area, not a fixed category. It may be created, edited, viewed, or archived. Archiving intentionally retains its connected work. iPhone emphasizes an approachable overview and detail view; macOS provides sidebar-based management; Watch only surfaces lightweight context.

## Hierarchy and action

Goals describe outcomes, Projects group the work needed to achieve them, and Tasks are the concrete actions. Orbit shows a task’s Project, Goal, and Orbit together so the person can see why the action matters. Assigning a task to a Project makes that Project’s Goal and Orbit authoritative, preventing contradictory hierarchy links.

## Capture Inbox

Quick capture records only a task title and enters it into `Inbox`. It deliberately does not infer or request an Orbit, Goal, Project, schedule, or estimate. Later organization is explicit, preserving both speed and user control.

## Time intelligence

Time capacity is local and explainable: manually available minutes minus calendar commitments and planned task effort. Orbit identifies free time and overload without requiring Calendar access; future EventKit integration will supply commitments only after permission.

## Energy

Energy is a voluntary productivity check-in: High, Good, Okay, Low, or Drained. Tasks can state their required energy. Orbit’s local matcher reports only match, mismatch, or unknown; it does not diagnose, interpret health, or infer energy without an explicit check-in.

## Recommendations

Orbit’s recommendation engine evaluates eligible tasks locally using priority, deadline urgency, Orbit weight, context, energy, time fit, historical momentum, and friction. Completed, cancelled, Inbox, and dependency-blocked tasks cannot be recommended. The score and its reasons are always inspectable; no remote AI API is used.

## Context

Context is an opt-in planning aid, not surveillance. Orbit currently lets the person select a simple local label—Home, Office, Campus, Commute, Outdoors, or Anywhere—and a short available window. The context engine combines that selection with time, energy, calendar availability when supplied, and the current device. It never continuously tracks location, invents a location after permission is denied, or records coordinates. Calendar and optional one-shot location integrations will remain useful only after explicit permission and will degrade to the same manual workflow when unavailable.

## Mac timeline

The Mac timeline is a deliberate planning surface, not an automatic scheduler. A person can drag an action to an hour, select a precise start, resize its duration, or remove it from the timeline. Orbit shows free blocks and detects conflicts. If a placement overlaps a calendar commitment or another task, it asks for confirmation and never rearranges the rest of the day silently.
