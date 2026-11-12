#!/usr/bin/env bash
# ossify state engine. §9.2 safety commitments: atomic writes, lock file,
# schema_version+migrations, append-only mutations journal.

OSS_STATE_SCHEMA_VERSION=4

_oss_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

oss_state_init() { # $1=state-file $2=project-name
  local sf="$1" name="$2" tmp
  [ -e "$sf" ] && { echo "oss: state already exists: $sf" >&2; return 1; }
  mkdir -p "$(dirname "$sf")" || return 1
  # §9.2: every state write goes temp+mv. A crash/disk-full mid-write must not
  # leave a truncated file that the "refuse if exists" guard then treats as a
  # valid existing state, permanently wedging the project.
  tmp="$(mktemp "${sf}.tmp.XXXXXX")" || return 1
  if ! jq -n --arg name "$name" --argjson sv "$OSS_STATE_SCHEMA_VERSION" '{
    schema_version:$sv,
    project:{name:$name,posture:null,composition_root:null,overlay_wiring:null},
    counters:{demo_line:0},
    releases:[],spines:[],work_items:[],
    demo_ledger:[],bones:[],risk_gates:[],fakes:[],
    feature_map:[],patch_records:[],class_overrides:[],veto_dispositions:[],
    close_records:[],
    mutations:[]
  }' > "$tmp"; then
    rm -f "$tmp"; return 1
  fi
  # never install an unparseable/empty skeleton
  if ! jq -e '.schema_version' "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"; echo "oss: init produced invalid state; aborted" >&2; return 1
  fi
  # base snapshot: temp+mv too (from the validated skeleton, before it moves)
  local btmp
  btmp="$(mktemp "${sf}.base.tmp.XXXXXX")" || { rm -f "$tmp"; return 1; }
  cp "$tmp" "$btmp" || { rm -f "$tmp" "$btmp"; return 1; }
  mv "$btmp" "$sf.base.json" || { rm -f "$tmp" "$btmp"; return 1; }
  mv "$tmp" "$sf" || { rm -f "$tmp"; return 1; }
}

oss_state_read() { jq -r "$2" "$1"; }

# Pure transform: op+payload applied to state on stdin -> new state on stdout.
# Shared by mutate (live) and replay (Task 4). Every new op lands HERE only.
_oss_apply_op() { # $1=op $2=payload-json
  local op="$1" payload="$2"
  case "$op" in
    set_posture)
      jq --argjson p "$payload" '.project.posture = $p.posture' ;;
    set_composition)
      jq --argjson p "$payload" '.project.composition_root = $p.composition_root' ;;
    set_overlay)
      jq --argjson p "$payload" '.project.overlay_wiring = $p.overlay_wiring' ;;
    add_release)
      jq --argjson p "$payload" '.releases += [$p]' ;;
    add_spine)
      jq --argjson p "$payload" '.spines += [$p]' ;;
    add_work_item)
      jq --argjson p "$payload" '.work_items += [$p]' ;;
    set_spine_class)
      jq --argjson p "$payload" '
        (.spines[] | select(.id == $p.spine) | .class) = $p.to
        | .class_overrides += [{spine:$p.spine,from:$p.from,to:$p.to,reason:$p.reason,at:$p.at}]' ;;
    add_bone)      jq --argjson p "$payload" '.bones += [$p]' ;;
    add_risk_gate) jq --argjson p "$payload" '.risk_gates += [$p]' ;;
    set_risk_gate_controls)
      # first()-targeted: a duplicate name would otherwise take the correction on
      # BOTH entries. This verb's own duplicate refusal is pre-lock (#305), so two
      # of ITS calls can interleave, and this bounds that to one target,
      # identically on live apply and replay. A duplicate MINTED by an add verb is
      # no longer a source: add_bone and add_risk_gate pass their uniqueness rail
      # into oss_state_mutate as its $5 guard, which runs inside that lock.
      jq --argjson p "$payload" '(first(.risk_gates[] | select(.name == $p.name)) | .controls) = $p.controls' ;;
    # COMPATIBILITY CONTRACT (1.11.0): the op names set_bone_touch and
    # set_risk_gate_touch, and their payload keys {adr,touch} and {name,touch},
    # are already in live journals, so neither may be renamed or reshaped.
    # Replay is only HALF that enforcement, and claiming otherwise overclaims
    # it. An op-NAME rename fails loudly here ("unknown op", rc 4). A payload
    # reshape does NOT fail, and it fails in TWO different ways, so neither mode
    # is a safe default to describe (#532):
    #   - an IDENTIFIER key renamed (`adr` -> `adr_ref`) is a silent no-op WHILE
    #     every bone carries its `adr`: `$p.adr` reads null, `first(.bones[] |
    #     select(.adr == null))` matches nothing, and jq assigns to an empty path
    #     at rc 0, identically on live apply and on replay. It is NOT a no-op for
    #     a row whose `adr` is null or absent: `select(.adr == null)` matches
    #     THAT row, and the assignment then overwrites its touch. Measured on a
    #     hand-built adr-less row, replaced at rc 0.
    #   - a VALUE key renamed (`touch` -> `surface`) is DESTRUCTIVE: `$p.touch`
    #     reads null, `first()` DOES match on the identifier, and the assignment
    #     writes `.touch = null` at rc 0. Replay stays clean (it re-applies the
    #     same transform), and the damage surfaces at the next reader: ONE nulled
    #     row makes EVERY touch_check answer rc 2 "cannot read bones ...
    #     INCONCLUSIVE, not clean", not only the damaged surface's - the read is
    #     a single pass over `.bones` and the first null aborts it. Measured on a
    #     two-bone fixture with one row nulled: rc 2 for the healthy bone's path
    #     as well, so reclassification and the release-close docs triggers are
    #     disabled project-wide, not for one surface.
    # The payload keys are held by this contract and by the verbs' own tests
    # (test-registries.sh pins the journaled [op, payload] exactly), not by
    # replay. first()-targeted for the same check-to-append race reason as
    # set_risk_gate_controls.
    set_bone_touch)
      jq --argjson p "$payload" '(first(.bones[] | select(.adr == $p.adr)) | .touch) = $p.touch' ;;
    set_risk_gate_touch)
      jq --argjson p "$payload" '(first(.risk_gates[] | select(.name == $p.name)) | .touch) = $p.touch' ;;
    # 1.22.0 (#305 item 2): a bone's title and revisit trigger, amended the way
    # set_bone_touch amends its surface - first()-targeted, same contract: the op
    # names and the payload keys {adr,title} and {adr,revisit_trigger} are live
    # journal vocabulary from this release on, pinned by test-registries.sh.
    set_bone_title)
      jq --argjson p "$payload" '(first(.bones[] | select(.adr == $p.adr)) | .title) = $p.title' ;;
    set_bone_revisit)
      jq --argjson p "$payload" '(first(.bones[] | select(.adr == $p.adr)) | .revisit_trigger) = $p.revisit_trigger' ;;
    add_fake)      jq --argjson p "$payload" '.fakes += [$p]' ;;
    add_feature)   jq --argjson p "$payload" '.feature_map += [$p]' ;;
    add_demo_line)
      jq --argjson p "$payload" '.demo_ledger += [$p] | .counters.demo_line += 1' ;;
    # Guarded (not `.quarantined_in_release = (if … then $p.release else
    # .quarantined_in_release end)`): jq's `.a = .a` CREATES `a` as null when
    # absent, so an unconditional write made replay of any journal entry
    # written before this guard existed (no `release` key at all) rebuild a
    # record the original transform never produced -> replay drift, rc 5. The
    # same unconditional form also ERASED an already-recorded release on a
    # re-quarantine with no release arg ("r0" -> ""), destroying §6.1's
    # parking-ticket anchor. One clause fixes both: only ever touch the key
    # when this call is a quarantine AND actually carries a release.
    # The deferred and escaped clauses use the same guard, for the same replay reason.
    #
    # #760 F2: the optional `from` key makes a status write atomic with respect to
    # the status its caller read. The verbs' pre-checks give the readable refusals
    # (they name the line's current status), but they run BEFORE the lock, so a defer
    # or an applied retire landing in between was overwritten by a write that had
    # already decided. With `from` present the op changes only a line whose CURRENT
    # status is in that array - evaluated here, inside the critical section - and
    # leaves every other line byte-identical. Absent `from` is the pre-1.16 payload
    # shape and behaves exactly as before, so old journals still replay.
    set_demo_line_status)
      jq --argjson p "$payload" '
        (.demo_ledger[] | select(.id == $p.id)) |=
          (. as $l
           | if ($p.from // null) != null and (($p.from | index($l.status)) == null)
             then .
             else (.status = $p.status | .status_reason = $p.reason | .status_by = $p.by
               | (if $p.status == "quarantined" and (($p.release // "") != "")
                  then .quarantined_in_release = $p.release
                  else . end)
               | (if $p.status == "deferred" and (($p.until // "") != "")
                  then .deferred_until_release = $p.until
                  else . end)
               | (if $p.status == "escaped" and (($p.clause // "") != "")
                  then .escape_clause = $p.clause
                  else . end))
             end)' ;;
    # F1 (user decision, 2026-07-31): a line carries a LIST of pending
    # amendments, one per spine - not a single slot. Two spines each planning
    # an amendment on the same line is real (verified live) and under the old
    # single-pending-slot model the second spine's plan silently overwrote the
    # first's; when the first spine closed, its amendment was already gone.
    # That is exactly the silent-coverage-loss harm D1 exists to prevent, so
    # the fix is structural, not a bigger guard: upsert-by-spine into a list.
    # A re-plan by the SAME spine replaces its own prior entry (update, not a
    # duplicate); a DIFFERENT spine's entry is untouched.
    set_demo_line_pending)
      jq --argjson p "$payload" '
        (.demo_ledger[] | select(.id == $p.id)) |=
          (.pending_amendments =
            (((.pending_amendments // []) | map(select(.by != $p.by)))
             + [{status:$p.status, by:$p.by, reason:$p.reason, at:$p.at}]))' ;;
    # Applies ONLY the closing spine's own amendment and consumes ONLY that
    # entry. A sibling spine's pending amendment on the SAME line survives
    # untouched - that is the whole point of the list. Lines with no
    # `pending_amendments` key at all (pre-migration/pre-amendment shape) read
    # as [] via `// []`, `$mine` comes back null, and the `else .` arm changes
    # nothing - it must NOT assign the key, or replaying a record that never
    # had one would diverge from a live state that never touched it.
    apply_demo_pending)
      jq --argjson p "$payload" '
        .demo_ledger |= map(
          (((.pending_amendments // []) | map(select(.by == $p.spine)))[0]) as $mine
          | if $mine != null
            then .status = $mine.status
               | .status_reason = $mine.reason
               | .status_by = $mine.by
               | .pending_amendments =
                   ((.pending_amendments // []) | map(select(.by != $p.spine)))
            else . end)' ;;
    # The escape hatch, now spine-scoped: clears only the CALLING spine's
    # pending amendment on the line. A sibling spine's pending amendment on
    # the same line is untouched - clearing every spine's entry indiscrimi-
    # nately would be the same silent-coverage-loss footgun F1 exists to fix,
    # just moved from set to clear.
    #
    # Back-compat fallback (G1, second fix round): a journal entry written by
    # a build before this op gained the `spine` argument carries `{id}` only.
    # Under an unconditional `.by != $p.spine`, `$p.spine` reads as null for
    # such a payload and `select(.by != null)` matches every real entry (`.by`
    # is never null on one that exists) - clearing NOTHING and silently
    # resurrecting the unplanned amendment on replay. `has("spine")` falls
    # back to the pre-existing op's actual behavior - clear every entry on the
    # line - which is exactly what that build's caller intended and produced.
    clear_demo_pending)
      jq --argjson p "$payload" '
        (.demo_ledger[] | select(.id == $p.id)) |=
          (.pending_amendments =
            (if ($p | has("spine"))
             then ((.pending_amendments // []) | map(select(.by != $p.spine)))
             else [] end))' ;;
    set_fake_status)
      jq --argjson p "$payload" '
        (.fakes[] | select(.boundary == $p.boundary)) |=
          (.status = $p.status | .status_reason = $p.reason | .status_at = $p.at
           | .expiry_release = (if $p.expiry == "" then .expiry_release else $p.expiry end))' ;;
    add_patch_record)
      jq --argjson p "$payload" '.patch_records += [$p]' ;;
    set_release_meta)
      # Allowlist the patch to exactly the five fields the plan names
      # (exit_criteria/spine_dag/ledger_budget/next_sketch/real_use_findings).
      # An unrestricted `. + $p.patch` would let a caller-controlled object
      # splice ANY key onto the release record (e.g. id/status), silently
      # corrupting identity or lifecycle state. Disallowed keys are dropped
      # (not rejected): this keeps the op total/pure for replay - a
      # rejecting op would need a new rc through _oss_apply_op, colliding
      # with the existing rc-4 apply-failure convention that op already
      # shares with every other case in this function.
      jq --argjson p "$payload" '
        ($p.patch | with_entries(select(.key | IN("exit_criteria","spine_dag","ledger_budget","next_sketch","real_use_findings")))) as $allowed
        | (.releases[] | select(.id == $p.release)) |= (. + $allowed)' ;;
    add_veto_disposition)
      jq --argjson p "$payload" '.veto_dispositions += [$p]' ;;
    # Status transitions. Each is a pure jq assignment through a select(), which
    # is a NO-OP on a non-matching id (jq assigns to an empty path expression and
    # exits 0). That silent no-op is exactly finding 7's `class_set` bug shape, so
    # the reject-before-mutate guard in entities.sh is load-bearing, not defensive
    # decoration - it is the ONLY thing that turns a typo'd id into rc 7.
    set_spine_status)
      jq --argjson p "$payload" '(.spines[] | select(.id == $p.spine) | .status) = $p.status' ;;
    set_work_item_status)
      jq --argjson p "$payload" '(.work_items[] | select(.id == $p.work_item) | .status) = $p.status' ;;
    # 1.22.0 (#335): name-only renames. Nothing but the name or title changes;
    # the verbs resolve exactly one record inside the lock, as the status verbs do.
    set_spine_name)
      jq --argjson p "$payload" '(.spines[] | select(.id == $p.spine) | .name) = $p.name' ;;
    set_work_item_title)
      jq --argjson p "$payload" '(.work_items[] | select(.id == $p.work_item) | .title) = $p.title' ;;
    set_release_status)
      jq --argjson p "$payload" '(.releases[] | select(.id == $p.release) | .status) = $p.status' ;;
    # 1.36.0 (#434): spec_oid is SET-IF-GIVEN. Only a payload that carries the key touches
    # it, so a journal entry written before 1.36.0 replays byte-identical (an unconditional
    # `.spec_oid = $p.spec_oid` would create the key as null on replay), and a 4-argument
    # re-dispatch never erases a recorded value.
    set_work_item_exec)
      jq --argjson p "$payload" '
        (.work_items[] | select(.id == $p.work_item)) |=
          (.branch = $p.branch | .worktree_path = $p.worktree_path | .base_sha = $p.base_sha
           | if ($p | has("spec_oid")) then .spec_oid = $p.spec_oid else . end)' ;;
    set_work_item_pr)
      jq --argjson p "$payload" '(.work_items[] | select(.id == $p.work_item) | .pr_url) = $p.pr_url' ;;
    # #133: the base each hosting repo's spine branch was cut from, recorded at
    # cut time so a re-entering /run-spine never re-derives it from HEAD (which
    # is the spine branch by then). A map keyed by repo; `+` keeps other repos.
    set_spine_base)
      jq --argjson p "$payload" '
        (.spines[] | select(.id == $p.spine)) |=
          (.bases = ((.bases // {}) + {($p.repo): $p.base_branch}))' ;;
    # #673 D1: the sanctioned CORRECTION for a recorded base. Same payload and
    # same assignment as set_spine_base; a distinct op so the journal shows the
    # overwrite as what it is. The refusal to overwrite lives in
    # set_spine_base's guard, not here - this op is the route the guard's
    # message names, and the entity-level verb validates its input exactly as
    # the setter does.
    reset_spine_base)
      jq --argjson p "$payload" '
        (.spines[] | select(.id == $p.spine)) |=
          (.bases = ((.bases // {}) + {($p.repo): $p.base_branch}))' ;;
    # #133: the 3-dispatch cap survives a respawned session. `// 0` reads a
    # legacy item as never dispatched; a non-number makes jq fail, which is the
    # rc-4 apply failure - never a silent reset.
    incr_work_item_dispatches)
      jq --argjson p "$payload" '
        (.work_items[] | select(.id == $p.work_item)) |=
          (.dispatches = ((.dispatches // 0) + 1))' ;;
    # §9.2's migration registry, realized. Pure, TOTAL and VERSION-AGNOSTIC:
    # replay re-applies it from the base snapshot (v1 or v2, whichever the
    # project started from) so base+journal still rebuilds live exactly and
    # the base is never rewritten. Every clause is `has(...)`-guarded, so a
    # v1 state (no close_records, no pending_* at all) and a v2 state (scalar
    # pending_* fields) both land on the same v3 shape in one call, and
    # calling it again on an already-current state is a no-op on every clause.
    #
    # v2->v3 (F1, 2026-07-31): a demo line's pending amendment moves from four
    # scalar fields to a `pending_amendments` LIST, because the scalar shape
    # can hold only one spine's plan at a time and a second spine planning on
    # the same line silently overwrote the first (the harm F1 exists to fix).
    # A v2 line with a set `pending_status` becomes a one-element list
    # carrying that spine's amendment; a v2 line with none becomes `[]`. The
    # scalar fields are then removed - the list is the only representation
    # going forward, so nothing reads the old fields once migrated.
    #
    # v3->v4 (1.16.0): a NO-OP on every field but the version, and deliberately
    # so. v4 exists for three demo-line statuses this release adds - `planned`,
    # `deferred` and `escaped` - which an older build does not know: a 1.15.2
    # reading v4 state skips a `planned` line silently, because its runner
    # selects `active` and `quarantined` only, and reports a green demo over the
    # lines it never ran. Nothing about the v3 SHAPE is wrong, so there is
    # nothing to translate; the bump is what makes that older build refuse the
    # state instead (rc 6, "requires a newer ossify") rather than misread it.
    # An older `demo_run` is read-only and checks no version, so it still runs; every
    # older mutation, `demo_record` included, refuses v4, so a close still cannot complete.
    migrate_schema)
      jq --argjson p "$payload" '
        (if has("close_records") then . else . + {close_records:[]} end)
        | .demo_ledger |= map(
            if has("pending_amendments") then .
            else
              .pending_amendments =
                (if (.pending_status // null) != null
                 then [{status: .pending_status, by: .pending_by,
                        reason: .pending_reason, at: .pending_at}]
                 else [] end)
              | del(.pending_status, .pending_by, .pending_reason, .pending_at)
            end)
        | .schema_version = $p.to' ;;
    # A close (work-item, spine, or release) leaves a durable record - the
    # demo runner previously wrote nothing to state, so there was no way to
    # prove after the fact that a close's demo actually ran. Pure append, same
    # shape as every other add_* op; both mutate and replay route through it.
    add_close_record)
      jq --argjson p "$payload" '.close_records += [$p]' ;;
    *)
      echo "oss: unknown op '$op'" >&2; return 4 ;;
  esac
}

# Mint a sequential id from the CURRENT (locked) state. Reuses the Plan A
# derivation helpers verbatim — the only change from Plan A is the call site:
# these now run INSIDE the mutate lock (state is stable), so two concurrent
# ceremonies cannot read the same max/counter and mint a duplicate id.
_oss_mint_id() { # $1=state-file $2=mint-spec (release | spine:<rel> | work_item:<spine> | demo)
  local sf="$1" spec="$2" kind parent
  kind="${spec%%:*}"; parent="${spec#*:}"; [ "$parent" = "$spec" ] && parent=""
  case "$kind" in
    release)   oss_id_next_release "$sf" ;;
    spine)     oss_id_next_spine "$sf" "$parent" ;;
    work_item) oss_id_next_work_item "$sf" "$parent" ;;
    demo)      echo "d$(( $(jq -r '.counters.demo_line' "$sf" 2>/dev/null || echo 0) + 1 ))" ;;
    *)         echo "oss: unknown mint spec '$spec'" >&2; return 4 ;;
  esac
}

oss_state_mutate() { # $1=state-file $2=op $3=payload-json [$4=mint-spec] [$5=uniqueness-guard-fn]
  local sf="$1" op="$2" payload="$3" mint="${4:-}" uniq="${5:-}" lock="$1.lock" rc=0
  # A project that was never initialised is not a project whose lock is held.
  # `mkdir "$lock"` below fails for BOTH reasons - the lock directory already
  # exists, or its parent `.ossify/` does not exist at all - and the single
  # diagnostic there reported the first for both, telling an uninitialised
  # project to "retry or run 'oss doctor'". doctor then correctly answers
  # `fail: state - not found`, so the two disagreed about one condition and the
  # remedy sent the user in a circle. The fix is `oss init`, so say that.
  #
  # rc 1 = generic/not-found per the taxonomy (lib/commands.sh's header note) and per
  # `doctor`'s own arm for this exact condition - NOT rc 3, which means a lock
  # genuinely is held, and not rc 5, which means drift.
  #
  # Placed BEFORE `mkdir "$lock"` for the same reason as the schema guard
  # below: a return after the lock is acquired jumps past the unconditional
  # `rmdir` and wedges the state file permanently.
  [ -f "$sf" ] || {
    echo "oss: no project state at $sf - run 'oss init <name>' first" >&2; return 1; }
  # §9.2 schema guard, on the WRITE path. doctor's call is advisory and
  # read-only and therefore protects nothing; without this line a v1 build
  # journals v1-semantics ops straight into a state claiming a future schema.
  #
  # Placed BEFORE `mkdir "$lock"` on purpose: a `return 6` after the lock is
  # acquired would jump past the unconditional `rmdir` below and wedge the state
  # file permanently.
  #
  # Gated on the file PARSING first so an unreadable/corrupt state keeps its
  # established rc 4 (apply-failure, original untouched) owned by
  # _oss_state_mutate_body, rather than being re-labelled a schema failure.
  #
  # `migrate_schema` is the ONE op that must run against a state this build's
  # guard would otherwise refuse - gating it would make the migration
  # unreachable and wedge every v1 project permanently. Still placed BEFORE
  # `mkdir "$lock"`: a `return 6` after the lock jumps past the unconditional
  # `rmdir` below and wedges the state file.
  if [ "$op" != "migrate_schema" ] && jq -e . "$sf" >/dev/null 2>&1; then
    oss_state_check_version "$sf" || return 6
  fi
  if ! mkdir "$lock" 2>/dev/null; then
    echo "oss: state locked ($lock exists) - another ceremony is mutating. If none is, the lock leaked from an interrupted run: ossify's doctor skill reports it, with staleness, once it is >30min old (invoke the ossify:doctor skill - NOT a bare /doctor, which is Claude Code's own panel); or rmdir it yourself after confirming no ceremony is running" >&2
    return 3
  fi
  # Critical section runs as a body function invoked in `|| rc=$?` context:
  # errexit is SUSPENDED for the whole body, so no bare command-substitution
  # inside it can hard-exit and leak the lock. The body echoes the minted id
  # (if any) to stdout on success; that stdout flows through this function.
  _oss_state_mutate_body "$sf" "$op" "$payload" "$mint" "$uniq" || rc=$?
  rmdir "$lock" 2>/dev/null || true
  return "$rc"
}

# Critical-section body. rc 0 ok, 4 on any failure, or the uniqueness guard's own
# 7 when it refuses the mint. NO lock logic here - the wrapper owns lock
# acquire/release. Minting happens here (inside the lock); the minted id is
# injected into the payload BEFORE journaling so the journal format and
# _oss_apply_op are unchanged (replay stays byte-identical).
_oss_state_mutate_body() { # $1=state-file $2=op $3=payload $4=mint-spec $5=uniqueness-guard-fn
  local sf="$1" op="$2" payload="$3" mint="${4:-}" uniq="${5:-}" tmp seq ts minted_id="" urc=0
  tmp="$(mktemp "${sf}.tmp.XXXXXX")" || return 4
  if [ -n "$mint" ]; then
    minted_id="$(_oss_mint_id "$sf" "$mint")" || { rm -f "$tmp"; return 4; }
    [ -n "$minted_id" ] || { rm -f "$tmp"; echo "oss: id minting produced empty id" >&2; return 4; }
    # Inject the minted id, overriding any caller-supplied id (a caller can
    # never win a race by pre-baking an id).
    payload="$(printf '%s' "$payload" | jq -c --arg id "$minted_id" '. + {id:$id}')" \
      || { rm -f "$tmp"; return 4; }
  fi
  seq="$(jq '.mutations | length' "$sf" 2>/dev/null)" || { rm -f "$tmp"; return 4; }
  ts="$(_oss_now)" || { rm -f "$tmp"; return 4; }
  # $5 = an OPTIONAL uniqueness guard (#305): the NAME of a function called with
  # ($1=state-file, $2=the payload about to be minted) HERE, inside the critical
  # section and immediately before the append. It returns 0 to let the mint
  # through, or 7 to refuse it having printed its own message; any other rc is a
  # guard failure and fails CLOSED at 4 - never mint on a rail that could not
  # answer.
  #
  # WHY IT LIVES IN HERE RATHER THAN IN THE CALLER'S VERB: a verb-side check runs
  # BEFORE this lock is acquired, so it is a check-to-append race - two ceremonies
  # both read "no such ref", then serialize on the lock, and the second one
  # appends a second row for one key, which is the unrepairable state #305 is
  # about, entered by two conforming callers. Measured on the verb-side version:
  # two concurrent `oss bone_add ADR-Rn` each exited 0 and left two rows for
  # ADR-Rn, with the window being the caller's own jq spawn between its count and
  # this lock. Deliberately AFTER the `seq` read above: a corrupt state keeps its
  # established rc 4 there rather than being re-labelled by the guard's read.
  if [ -n "$uniq" ]; then
    urc=0; "$uniq" "$sf" "$payload" || urc=$?
    if [ "$urc" -ne 0 ]; then
      rm -f "$tmp"
      [ "$urc" -eq 7 ] || { echo "oss: the uniqueness guard could not answer (rc $urc); refusing to mint" >&2; return 4; }
      return 7
    fi
  fi
  # journal append + effect in ONE jq pipeline into ONE $tmp, committed by a
  # single mv - mutation and journal entry commit atomically.
  if ! jq --arg op "$op" --arg ts "$ts" --argjson seq "$seq" --argjson payload "$payload" \
      '.mutations += [{seq:$seq,op:$op,ts:$ts,payload:$payload}]' "$sf" \
      | _oss_apply_op "$op" "$payload" > "$tmp"; then
    rm -f "$tmp"; return 4
  fi
  if ! jq -e '.schema_version' "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    echo "oss: mutation produced invalid state; aborted (original untouched)" >&2
    return 4
  fi
  mv "$tmp" "$sf" || { rm -f "$tmp"; return 4; }
  # Report the minted id (success only). Explicit `return 0`: a bare
  # `[ -n "$minted_id" ] && printf ...` as the last line would make the
  # function return 1 for non-mint ops (empty minted_id) - a false failure.
  [ -n "$minted_id" ] && printf '%s\n' "$minted_id"
  return 0
}

# §9.2 replay capability: rebuild state from the base snapshot by re-applying
# every journaled mutation through the SAME pure transform mutate uses
# (_oss_apply_op), re-appending each mutation record to .mutations first so a
# faithful replay reproduces the live state including the journal itself.
# The journal length, validated. `jq '.mutations | length'` EXITS 0 and yields
# the digit `0` when .mutations is missing or null, and yields EMPTY OUTPUT for a
# 0-byte file. Both were previously read as "a journal of length 0", which made
# the rebuild loop a no-op and let `cat "$base"` - the pristine init skeleton -
# be committed over a live project at rc 0 with a success message. The
# `type == "array"` test is the load-bearing half: the digits-only guard alone
# passes the missing-key case, because that case really does produce `0`.
# Sets $_OSS_JOURNAL_LEN on success. rc 6 = the journal itself is corrupt.
_OSS_JOURNAL_LEN=""
_oss_journal_len() { # $1=state-file
  local sf="$1" n
  jq -e '.mutations | type == "array"' "$sf" >/dev/null 2>&1 || {
    echo "oss: the journal in '$sf' is missing or is not an array - base+journal cannot rebuild this state" >&2
    return 6
  }
  n="$(jq '.mutations | length' "$sf" 2>/dev/null)" || return 6
  case "$n" in ''|*[!0-9]*) echo "oss: unreadable journal length in '$sf'" >&2; return 6 ;; esac
  _OSS_JOURNAL_LEN="$n"
}

# Read-only against $sf (only $sf.base.json's content is read into memory) -
# doctor (Task 5) can call this freely without a lock.
oss_state_replay() { # $1=state-file ; rc 0 = clean, 5 = drift, 1 = no base, 6 = corrupt journal
  local sf="$1" base="$1.base.json" rebuilt live n i op payload seq_json
  [ -f "$base" ] || { echo "oss: no base snapshot ($base)" >&2; return 1; }
  rebuilt="$(cat "$base")" || return 1
  _oss_journal_len "$sf" || return $?
  n="$_OSS_JOURNAL_LEN"
  i=0
  while [ "$i" -lt "$n" ]; do
    seq_json="$(jq -c ".mutations[$i]" "$sf" 2>/dev/null)" || { echo "oss: mutation $i unreadable" >&2; return 4; }
    op="$(printf '%s' "$seq_json" | jq -r '.op' 2>/dev/null)" || { echo "oss: mutation $i op unreadable" >&2; return 4; }
    payload="$(printf '%s' "$seq_json" | jq -c '.payload' 2>/dev/null)" || { echo "oss: mutation $i payload unreadable" >&2; return 4; }
    rebuilt="$(printf '%s' "$rebuilt" \
      | jq --argjson m "$seq_json" '.mutations += [$m]' \
      | _oss_apply_op "$op" "$payload")" || return 4
    i=$((i+1))
  done
  live="$(jq -S . "$sf" 2>/dev/null)" || { echo "oss: cannot read live state $sf" >&2; return 1; }
  if [ "$(printf '%s' "$rebuilt" | jq -S .)" = "$live" ]; then
    echo "replay: clean ($n mutations)"
  else
    # Say only what is true today. The previous message pointed the operator at
    # `oss doctor` for repair, but doctor is replay's ONLY caller (so it told an
    # operator running doctor to run doctor) and no repair/restore verb exists in
    # this build. Naming a command that cannot repair is worse than naming none:
    # the operator's next move becomes deleting the state file, which destroys
    # the journal living inside it. `$rebuilt` is deliberately NOT written from
    # here — this function is lock-free so doctor can call it freely.
    # This branch is reached ONLY with an intact journal - a corrupt one returns
    # rc 6 from _oss_journal_len above and never gets here. That matters: the
    # "Nothing is lost" promise and the state_restore remedy are both TRUE for
    # drift and both FALSE when the journal is what is damaged, where restore
    # would complete the loss rather than repair it.
    echo "replay: drift detected - live state does not equal base+journal ($n mutations)." >&2
    echo "  Nothing is lost: the base snapshot ($base) and the append-only journal inside $sf are both intact, so the correct state is still derivable from them." >&2
    echo "  Recover with 'oss state_restore', which rebuilds the state from '$base' plus the journal under the state lock. Do NOT delete $sf - the journal lives inside it." >&2
    return 5
  fi
}

# §9.2: "corruption recovery = replay from last good snapshot". oss_state_replay
# is the comparator and is deliberately lock-free (doctor calls it freely), so it
# must NOT write. This is the writer: it takes the lock, rebuilds from
# base+journal through the SAME pure transform, and commits via temp+rename.
oss_state_restore() { # $1=state-file ; rc 0 restored-or-already-clean, 1 no base, 4 apply, 3 lock
  local sf="$1" base="$1.base.json" lock="$1.lock" rc=0
  [ -f "$base" ] || { echo "oss: no base snapshot ($base) - nothing to restore from" >&2; return 1; }
  if oss_state_replay "$sf" >/dev/null 2>&1; then
    echo "restore: state is already clean - nothing to do"
    return 0
  fi
  if ! mkdir "$lock" 2>/dev/null; then
    echo "oss: state locked ($lock exists) - another ceremony is mutating. If none is, the lock leaked from an interrupted run: ossify's doctor skill reports it, with staleness, once it is >30min old (invoke the ossify:doctor skill - NOT a bare /doctor, which is Claude Code's own panel); or rmdir it yourself after confirming no ceremony is running" >&2
    return 3
  fi
  _OSS_RESTORE_APPLIED=""
  _oss_state_restore_body "$sf" "$base" || rc=$?
  rmdir "$lock" 2>/dev/null || true
  # Report what the rebuild ACTUALLY replayed, not a count re-derived by
  # re-reading the file we just wrote - that form cannot contradict the write,
  # which is the tautology this suite has been bitten by before.
  [ "$rc" -eq 0 ] && echo "restore: rebuilt from base + ${_OSS_RESTORE_APPLIED:-?} journaled mutations"
  return "$rc"
}

# Critical section. Same `|| rc=$?` body-function pattern as oss_state_mutate:
# errexit is suspended for the whole body, so no bare command substitution in
# here can hard-exit between lock-acquire and lock-release and leak the lock.
_oss_state_restore_body() { # $1=state-file $2=base
  local sf="$1" base="$2" rebuilt n i seq_json op payload tmp
  rebuilt="$(cat "$base")" || return 4
  # Refuse a corrupt journal rather than rebuilding the empty base over a live
  # project. Without this the loop below is skipped and `cat "$base"` wins.
  _oss_journal_len "$sf" || return $?
  n="$_OSS_JOURNAL_LEN"
  i=0
  while [ "$i" -lt "$n" ]; do
    seq_json="$(jq -c ".mutations[$i]" "$sf" 2>/dev/null)" || return 4
    op="$(printf '%s' "$seq_json" | jq -r '.op' 2>/dev/null)" || return 4
    payload="$(printf '%s' "$seq_json" | jq -c '.payload' 2>/dev/null)" || return 4
    rebuilt="$(printf '%s' "$rebuilt" \
      | jq --argjson m "$seq_json" '.mutations += [$m]' \
      | _oss_apply_op "$op" "$payload")" || return 4
    i=$((i+1))
  done
  tmp="$(mktemp "${sf}.tmp.XXXXXX")" || return 4
  printf '%s' "$rebuilt" > "$tmp" || { rm -f "$tmp"; return 4; }
  if ! jq -e '.schema_version' "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"; echo "oss: restore produced invalid state; aborted (original untouched)" >&2; return 4
  fi
  # Keep the pre-restore file so a wrong restore is recoverable by hand. Best
  # effort: a failure to copy must not block a restore that is otherwise sound.
  cp "$sf" "$sf.pre-restore" 2>/dev/null || true
  mv "$tmp" "$sf" || { rm -f "$tmp"; return 4; }
  _OSS_RESTORE_APPLIED="$i"
}

# §9.2 schema-version guard (no silent upgrades): refuse to operate on a state
# file whose schema_version is newer than this build supports, and name the
# gap rather than guess. Migration registry lives HERE: a future v1->v2
# migration is added as an explicit, journaled `_oss_migrate_1_to_2` case
# dispatched from this function once a v2 schema exists - never silent.
oss_state_check_version() { # $1=state-file ; rc 0 ok, 6 missing/invalid/future
  local v
  # Guarded with `|| v=""` (deviates from the brief's bare
  # `v="$(jq ... 2>/dev/null)"`): a bare assignment's exit status IS the
  # command substitution's exit status, so a missing/unreadable state file
  # (jq rc!=0) would trip `errexit` in any caller that isn't already
  # suspending it (e.g. this function called directly, not if-wrapped) -
  # silently killing the process instead of returning the documented rc 6.
  # doctor.sh always calls this if-wrapped (which does suspend errexit for
  # the whole call), but the function's own contract promises rc 6 for
  # missing/invalid regardless of call site, so guard it here too.
  v="$(jq -r '.schema_version // empty' "$1" 2>/dev/null)" || v=""
  [ -n "$v" ] || { echo "state schema missing/invalid" >&2; return 6; }
  # Reject any non-digit value (e.g. "abc", "1.5", a JSON boolean) BEFORE the
  # numeric `-gt` comparison. Without this a valid-JSON-but-non-integer
  # schema_version makes `[ "$v" -gt N ]` error ("integer expression
  # expected"); inside the `if` that nonzero exit reads as "not newer" and
  # execution silently falls through to `return 0` - the exact §9.2
  # silent-acceptance the guard exists to prevent. Digits-only here
  # guarantees the `-gt` below is always a numeric comparison.
  case "$v" in
    ''|*[!0-9]*) echo "state schema invalid: '$v'" >&2; return 6 ;;
  esac
  if [ "$v" -gt "$OSS_STATE_SCHEMA_VERSION" ] 2>/dev/null; then
    echo "state schema v$v requires a newer ossify (this build supports v$OSS_STATE_SCHEMA_VERSION)" >&2
    return 6
  fi
  # A state OLDER than this build is refused too, and told what to run. Silently
  # operating on a v1 state with v2 semantics is the same class of failure as
  # operating on a v99 one - §9.2 binds "an explicit migration policy ... never
  # silent" in both directions. The refusal names the command so the operator's
  # next move is `oss migrate`, not deleting the state file.
  if [ "$v" -lt "$OSS_STATE_SCHEMA_VERSION" ]; then
    echo "state schema v$v predates this build (v$OSS_STATE_SCHEMA_VERSION) - run 'oss migrate' to upgrade it" >&2
    return 6
  fi
  return 0
}
