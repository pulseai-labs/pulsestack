---
scenario_id: 02-destructive-gate-generic-confirm-no-touch
expected_register: yes
expected_controls: paper env,human confirm,audit trail,progressive exposure
---
A skeleton ships an admin purge path at `src/admin/purge.rs` that deletes user data; data destroyed is gone and a test failure cannot undo it, so the defect character is the destructive family. The proposed registration records the controls as a generic "are you sure?" confirmation plus an append-only audit trail, and records no touch surface glob. The skeleton reaches this surface in Release 0. A bone about the purge design also applies, but the team has not registered it.
