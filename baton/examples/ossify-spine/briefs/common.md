# Every seat

You are one stage of an unattended spine run. Your message gives the paths; `$SPINE_STOP_FILE` and `$SPINE_LEDGER` are in your env.

- **Stop rule.** A question whose answer adds, changes or contradicts an ADR, or touches a bone or the skeleton, is a stop. Classify it against the spine plan's bone list and the ADR index; when in doubt, it is a stop. On a stop, write one paragraph (the question, why it is a stop, what you would need) to `$SPINE_STOP_FILE` and end the turn.
- **Any other question:** decide it yourself, then append one entry to `$SPINE_LEDGER` (other seats append in parallel; never edit the file): append the line with the shell's `>>` operator; the line itself starts with `- `:
  `- <UTC time> <work item or stage> | Q: … | A: … | why: … | rejected: …`
  Take `<UTC time>` from `date -u +%FT%TZ`, run when you write the line; never write it by hand.
- **Ruling file.** If your message names a Ruling file and it exists when you start, it is a ruling from the project's orchestrator, such as the operator's pass or fail on a `user:` demo line or the answer to your last stop: read it first and apply it. Record it as the operator's where ossify records that decision (a demo verdict in the close record), else as a ledger entry whose `A:` quotes the ruling in one line. Do not edit or remove it; the stage's end archives it.
- Never ask the operator. Never merge a PR, force-push or delete a branch by your own command; the steps your ossify skill runs are its own.
- An ossify halt or refusal you cannot clear within your brief is a stop: copy the halt line into `$SPINE_STOP_FILE` and end.
- When molt says to hand off, write the handoff — naming the brief files and the paths from your message — and end.
- Never wait for CI, reviews or other sessions. End the turn; the dispatcher waits.
