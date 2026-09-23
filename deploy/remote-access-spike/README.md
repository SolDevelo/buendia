# Reverse-SSH tunnel — spike result

A measured alternative to Tailscale for field-pilot remote support (plan §3.5 / WS-7). The design:
the pilot server laptop dials out and holds a reverse SSH tunnel to a relay with a public IP;
support reaches the laptop through that relay. **Nothing listens on the laptop's real interfaces,
no inbound port is opened anywhere, and no AWS security group is touched.**

Status: **spike, not shipped.** Nothing here is wired into `setup.sh`. The remote-support path that
ships today is still Tailscale, disabled pending C1.

```
   pilot laptop                      relay (public IP)                 support
   ┌──────────────┐                  ┌───────────────┐                ┌──────────┐
   │ sshd         │                  │ sshd :22      │                │          │
   │ 127.0.0.1:22 │ ── ssh -N -R ──▶ │ 127.0.0.1:    │ ◀── ProxyJump ─│          │
   │ (loopback    │   (outbound,     │      12222    │   (support's   │          │
   │  ONLY)       │    port 22)      │  loopback only│    own key)    │          │
   └──────────────┘                  └───────────────┘                └──────────┘
```

## What was measured, and on what

Two rigs, because the real relay could not be reconfigured (below):

- **Real WAN path** — this workstation (behind NAT) → `msf-buendia-demo` (Ubuntu 22.04, eu-north-1).
  Proved the tunnel establishes across the internet through NAT, and that support reaches the far
  end in **one command in 1.3 s**.
- **Local rig** — two containers (`relay`, `client`) on a user-defined docker network, the relay
  configured to mirror the real one (`ClientAliveInterval 300`, `ClientAliveCountMax 3`,
  `GatewayPorts no`). Used for everything requiring sshd changes and for link-failure simulation.

### 1. It works, and the relay never holds the keys to the laptop

A single support command hops relay → laptop via `ProxyJump`, carrying support's own key:

```
ssh -F ssh_config_support buendia-pilot 'hostname'     # 1.288 s, cold
```

The relay holds **no** credential for the laptop. Proof it is genuinely absent: a login attempt
made *from* the relay reaches the laptop's sshd and is refused —
`buendia@127.0.0.1: Permission denied (publickey)` — which simultaneously proves the TCP path is
complete and that the relay cannot use it.

### 2. Recovery after link loss — the finding that decides the design

How fast the tunnel comes back depends entirely on **how** it died, and the difference is three
orders of magnitude. Measured:

| How the tunnel died | Relay frees the port | Tunnel usable again |
|---|---|---|
| Client process killed (`kill -9`) | immediately (socket closes, RST) | **12 s** (systemd `RestartSec`) |
| Link down < client timeout (30 s) | n/a — the TCP connection survived | **14 s**, same connection resumed |
| Link down > client timeout, then restored on the same IP | seconds (old socket RSTs on restore) | **5 s** |
| **Link blackholed, laptop gone (no RST ever reaches the relay)** | **`ClientAliveInterval` × `CountMax`** | **see below** |

The last row is the field case: Wi-Fi vanishes, the laptop is powered off, or it returns on a
different address. The relay's packets are dropped silently, so it keeps the session — and the
forwarded port — and the laptop **cannot** re-establish:

```
Error: remote port forwarding failed for listen port 12222
```

**Measured: 798 s — 13 minutes — before the port freed.** Reproduced deliberately (blackhole the old
client with `iptables -j DROP`, destroy it, bring up a fresh one on a different address), not inferred.

### 2a. The obvious fix does not work, and finding out why matters

The intuitive remedy is to lower the relay's SSH keepalive (`ClientAliveInterval` /
`ClientAliveCountMax`). **It does nothing.** Measured with `30 × 2` — a theoretical 60 s — the port
was still held at **405 s**.

The reason is visible on the relay while it is stuck:

```
tcp   0   4192   192.168.96.2:22   192.168.96.60:53008   ESTABLISHED
                 ^^^^ bytes stuck unacknowledged in the send queue
```

sshd's keepalive probes are *written into the socket* and never acknowledged. Because the kernel is
still retransmitting them, the write never fails, so sshd never reaches its "peer is not answering"
disconnect. The session survives until the **kernel** abandons the connection, after
`net.ipv4.tcp_retries2` retransmissions — the default 15 is ~13–15 minutes, which is exactly the
798 s observed.

**The lever is therefore the kernel's retransmission budget, on the relay:**

| Relay configuration | Port freed after |
|---|---|
| `ClientAlive 300×3`, `tcp_retries2=15` (stock) | **798 s** |
| `ClientAlive 30×2`, `tcp_retries2=15` | **still held at 405 s** |
| `ClientAlive 30×2`, **`tcp_retries2=6`** | **32 s** |

⚠️ `tcp_retries2` is **system-wide** — it shortens the retransmission budget for every TCP connection
on that host. That is fine on a relay whose only job is this tunnel, and not fine on a box also
serving something else. It is a second, independent reason the relay should be a dedicated instance.

### 3. `autossh` is not needed

A systemd unit with `Restart=always` does everything `autossh` was invented for, with one fewer
package on an offline box. Measured: process killed → **restarted in 12 s**, forward re-established
on the real relay automatically.

Offline behaviour (unroutable target, 100 s): **3 retries, 22 journal lines, 0.007 s CPU**. Cheap —
but at `RestartSec=10` that extrapolates to ~18 000 journal lines a day on a box that is offline
for weeks, so the shipped unit uses **`RestartSec=60`**.

### 4. The tunnel account can do nothing but forward

Each restriction was verified to bite, not assumed:

| Attempt | Result |
|---|---|
| Run a command | `This account is not available` |
| Get a PTY | `PTY allocation request failed on channel 0` |
| `-L` local forward | connection reset (`permitopen` mismatch) |
| Bind any other remote port | `remote port forwarding failed for listen port 13333` |

Two traps found the hard way, both of which present as a bare `Permission denied (publickey)` or a
correct-looking config that refuses to forward:

- **`permitopen="none"` is invalid in `authorized_keys`** (it is only an `sshd_config` keyword). An
  unparseable option makes sshd reject the entire key. Pin `-L` to a dead target instead.
- **`permitlisten` must match the bind address the client requests.** `-R 12222:...` sends an empty
  bind address and is refused by `permitlisten="127.0.0.1:12222"`; the client must use
  `-R 127.0.0.1:12222:...`.

### 5. Presence detection — do not trust the listening port

"Is the box online?" must be answered by demanding an **SSH banner through** the tunnel. During the
stale-port window the naive check is actively wrong — measured, with the laptop destroyed:

```
netstat -ltn | grep 12222   ->  "ONLINE"    # WRONG: stale listener
nc -w 5 127.0.0.1 12222 | head -c 4 | grep SSH  ->  OFFLINE   # correct
```

`presence-check.sh` implements the honest form.

## What blocked the spike, and what it implies

The relay's sshd restricts logins to `AllowUsers ubuntu`, so a dedicated tunnel account cannot log
in until that is changed — and **remote shell writes to that box were blocked by this environment's
permission policy**, so the sshd change could not be applied. The tunnel account
(`bt-spike`) created before the block was removed again; the relay is byte-for-byte as it was found
(verified: no `bt-spike` user, no drop-in in `/etc/ssh/sshd_config.d/`, `AllowUsers ubuntu`).

The real-WAN measurements therefore ran as the existing `ubuntu` account, and everything needing
sshd configuration ran on the local rig.

**The implication is a recommendation, not an inconvenience:** `msf-buendia-demo` is the wrong relay.
It is client-facing — MSF authors clinical profiles on it — and using it would mean relaxing its
login policy and adding a permanent inbound path for a laptop in the field. **A dedicated relay
instance (t4g.nano) should hold this role**, which also isolates the blast radius if the tunnel
account is ever abused. That is a new AWS resource, so it is the user's call, not the spike's.

## If the relay must listen on 443 (not implemented)

Corporate Wi-Fi may block outbound 22. Making the relay answer on 443 needs a security-group ingress
rule and `Port 22`+`Port 443` in the relay's sshd, then `-p 443` on the client. It costs nothing in
tunnel design, but it changes a client-facing box's exposure, so it is a decision rather than a
detail. Note this only buys *port* resilience: a proxy that inspects TLS will still see SSH on 443
and may drop it, which is precisely the case Tailscale's DERP relay handles and this design does not.

## Comparison with Tailscale

| | Reverse SSH tunnel | Tailscale |
|---|---|---|
| Behind NAT, no inbound | ✅ outbound 22 (or 443) | ✅ outbound, DERP fallback |
| Restrictive networks | ⚠️ one TCP port; blocked if that port is filtered | ✅ UDP, falls back to TCP/443 |
| Deep-packet inspection | ❌ recognisably SSH | ✅ TLS to DERP |
| Presence signal | ✅ banner probe on the relay | ✅ `tailscale status` |
| Reach the router/LAN too | ⚠️ one port per service, or a second `-R` | ✅ `--advertise-routes` |
| Third party in the path | ✅ none — you own every hop | ❌ coordination plane (C1 question) |
| Infrastructure to run | ❌ an EC2 relay, patched for the pilot's life | ✅ none |
| Public attack surface | ❌ an internet-facing sshd you own | ✅ no listener anywhere |
| Credential model | keys you issue and revoke by hand | tailnet ACL, revocable centrally |
| Effort to working state | ~half a day, plus the relay | already implemented in `setup.sh` |
| Failure mode found here | 13-min stale-port hole; needs a kernel sysctl on the relay, not just sshd config | node key expiry while offline |

## Recommendation

**Keep Tailscale as the primary path; hold this as the C1 fallback.**

The tunnel works, its security posture is arguably better (the laptop's sshd binds loopback only —
no listener on any real interface, which retires defect D3 outright rather than monitoring it), and
it puts no third party in the path. But it loses on the criterion that actually decides this
deployment: **surviving a network we do not control.** MSF corporate Wi-Fi is exactly where a single
outbound TCP port is most likely to be filtered, and this design has no fallback when it is, whereas
Tailscale's DERP relay is the reason that transport was chosen. It also trades zero infrastructure
for an internet-facing relay that must be patched for the pilot's life.

That calculus flips if C1 rejects a third-party coordination plane. Then the honest comparison is
this design versus **Headscale** (self-hosted control plane, same client, keeps DERP) — and the
reverse tunnel wins only on simplicity, which is worth having when the thing must work unattended
in DRC.

## Files

| File | What it is |
|---|---|
| `buendia-tunnel.service` | systemd unit for the laptop (replaces `autossh`) |
| `relay-sshd.conf.example` | relay sshd drop-in: `AllowUsers` and the tunnel-account limits |
| `relay-sysctl.conf.example` | **the setting that actually fixes stale-port recovery** |
| `authorized_keys.example` | the restriction line, with the two traps documented |
| `presence-check.sh` | honest "is it online" check, run on the relay |
| `support-ssh-config.example` | the support-side one-command hop |
| `TEARDOWN.md` | exactly what was created and removed, and how to clear the rig |
