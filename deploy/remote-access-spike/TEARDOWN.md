# Spike teardown record

## What was created on the RELAY (`msf-buendia-demo`, 13.49.56.51) — ALL REMOVED

| Created | Removed | Verification |
|---|---|---|
| user `bt-spike` (`useradd -m -s /usr/sbin/nologin`) | ✅ `userdel -r bt-spike` | `grep bt-spike /etc/passwd` → absent; only `ubuntu` has uid ≥ 1000 |
| `/home/bt-spike/.ssh/authorized_keys` | ✅ removed with the home dir | — |
| sshd config change (`AllowUsers`) | **never applied** — blocked by this environment's permission policy before it was written | `ls /etc/ssh/sshd_config.d/` → only the 3 original files; `sshd -T` → `allowusers ubuntu` |
| forwarded ports 12222/12223 | ✅ processes ended | `ss -ltn | grep 1222[0-9]` → none |

The relay is byte-for-byte as it was found. **No AWS resource was created and no security group was
touched.** Nothing was installed on it.

## What was created on THIS WORKSTATION — ALL REMOVED

- systemd **user** unit `buendia-tunnel-spike.service` — stopped, file deleted, daemon reloaded.
- systemd **user** unit `buendia-offline-spike.service` — stopped, file deleted.
- a `python3 -m http.server` helper on 127.0.0.1:8099 — killed.
- an entry in `~/.ssh/known_hosts` for `[127.0.0.1]:2022` — removed; all later spike SSH used a
  scratchpad `known_hosts`, so the user's file was not touched again.

## Local test rig — ALSO REMOVED

Containers `buendia-spike-relay` / `buendia-spike-client`, network `buendia-spike-net` and images
`buendia-spike-relay` / `buendia-spike-client-img` / `buendia-spike-sshd` were deleted after the
measurements. Verified: no spike containers, network or images remain.

## Still present

⚠️ The keypairs generated for the spike (`tunnel_key`, `client_key`, `support_key`) live only in the
scratchpad and are **not** in the repository. They authorise nothing now that the relay account is
gone, but delete the scratchpad if you want them gone entirely.

## Final verification (after teardown)

Re-checked against the baseline captured before any change:

```
users >= 1000 : ubuntu                       (bt-spike gone)
sshd_config.d : the 3 original files only    (no drop-in added)
allowusers    : ubuntu                        (unchanged)
clientalive   : 300 / 3                       (unchanged)
spike ports   : 0                             (nothing forwarded)
OpenMRS       : HTTP 308                      (demo server still serving MSF)
```
