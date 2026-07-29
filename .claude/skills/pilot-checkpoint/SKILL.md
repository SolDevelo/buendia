---
name: pilot-checkpoint
description: Close out a chunk of Buendia field-pilot work so the next session can pick it up — verify it runs, record new gotchas, update the progress and MSF-config docs, check the client submodule for stranded work, and commit. Use after finishing a workstream step or before ending a session, and whenever asked to "wrap up", "update the docs", or "commit this work".
---

# Check out of a pilot work session

`docs/FIELD-PILOT-PROGRESS.md` is the human-readable source of truth for a new session. It is only
worth that if it is updated *before* the context is lost. Work through this in order.

## 1. Verify it actually runs

```bash
deploy/tools/buendia-verify.sh
```

Claims in the progress doc are supposed to mean "built, booted and checked", not "looked right".
If something is unverified, say so explicitly in the doc rather than implying it passed.

## 2. Record what was learned

Two places, and they are not interchangeable:

- **A bug, a failure mode, or a non-obvious fact about the stack** → `FIELD-PILOT-PROGRESS.md` §4,
  with the symptom, the cause, and the recovery. That section is the single biggest time-saver in
  the project; most of the effort here went into EOL-stack and split-container traps.
- **A configuration question, or a default we invented ourselves** → `FIELD-PILOT-MSF-CONFIG-REQUESTS.md`,
  with the default shipped and the file it lands in. That file is what gets sent to MSF. A question
  left in a commit message or a chat thread is lost.

If a defect was found in a shipped tool (`deploy/` scripts, the seed, `tools/*`), fix it **in the
repo**, not just live in a running container.

## 3. Update the status doc

`FIELD-PILOT-PROGRESS.md`:
- **§2** — move items between *Done & verified* and *Not started / deferred*; keep it honest about
  what was actually exercised versus assumed.
- **§2 "State of the local test stack RIGHT NOW"** — if the stack was rebuilt, re-seeded or torn
  down, correct it. The next session trusts this to decide whether to reattach or rebuild.
- **§5** — the workstream table.
- **§8** — what the next session should start on.
- The date line at the top.

If scope changed, also update `FIELD-PILOT-DEPLOYMENT-PLAN.md` and the exec summary, and note the
change in the progress doc.

## 4. Check the client submodule for stranded work

Uncommitted work in `client/` is **nearly invisible** — the superproject shows only a bare
`m client`, and the next `git submodule update` silently discards it.

```bash
git submodule status
git -C client status --short
git -C client branch --show-current      # must be drc-pilot
```

Client changes are committed **in the submodule on `drc-pilot`** (`SolDevelo/buendia-client`) and
pushed, then the gitlink bump is committed in the superproject. Prefer making behaviour a gradle
`-P` property surfaced as an `APK_*` var in `deploy/.env` over editing a hardcoded constant — that
way it can be retuned without another client release.

## 5. Commit

```bash
git status --short
git add <the intended paths>          # never -A; see the strays below
git commit
```

- **Commit at every checkpoint.** Don't leave a working package only in the working tree.
- **Don't sweep up the pre-existing strays.** `tools/profile_applyc`, `docs/PROFILE-CSV-FORMAT.md`
  and an `.idea/` change predate this work and are pending review — they are not yours to commit.
- Heavy artefacts (the 80 MB base seed, `.war`/omods, `deploy/.env`, the keystore, `pkgserver/www/`,
  `cards/`) are git-ignored on purpose. `20-buendia-site.sql` is deliberately **not** ignored.
- Pushing is the user's call. The superproject branch has been carried unpushed for a while; the
  client submodule branch is pushed. Say which state you left it in.

## 6. Hand off

Close with a short summary of: what now works and was verified, what changed in the docs, what is
still open, and what the next session should do first. That summary and §8 of the progress doc
should agree.
