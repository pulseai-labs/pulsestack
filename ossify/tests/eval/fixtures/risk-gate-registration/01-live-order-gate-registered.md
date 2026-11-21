---
scenario_id: 01-live-order-gate-registered
expected_register: yes
expected_controls: paper env,human confirm,kill switch,audit trail,progressive exposure
---
A trading skeleton's Release 0 places live orders against a broker: charging a real card, spending API credits at scale, and moving money that is gone once moved. The defect character is the money family — a test failure cannot undo a filled order. Planned changes touch `src/exec/**,src/broker/**`. The proposed controls are: a paper/sandbox environment as the default target with real mode opt-in and explicit; a human confirm that names the concrete effect ("sell 200 shares of X at market"), not a generic "are you sure?"; a kill switch flag that halts the order class without a redeploy; an append-only audit trail of who/what/when/inputs/outcome; and progressive exposure shipping to one symbol first and widening on evidence. A bone about the broker-adapter design also applies.
