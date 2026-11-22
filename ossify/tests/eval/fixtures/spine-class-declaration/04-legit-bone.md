---
scenario_id: 04-legit-bone
expected_class: bone
---
A spine "introduce the event-sourcing persistence model" replaces the service's update-in-place tables with an append-only event log as the record of truth; every read table becomes a projection rebuilt from the log. Once a release writes production data as events, going back to update-in-place storage means migrating every stored record out of the log. The spine carries an actor-to-outcome journey that exercises the persistence model. The persistence model's planned files touch no already-registered bone's touch surface. No service extraction is proposed; the persistence model stays in the single deployable.
