# Troubleshooting: DNS / OpenAI EAI_AGAIN in Docker

## What is `getaddrinfo EAI_AGAIN`?

EAI_AGAIN is a temporary DNS failure. The container sent a DNS query but got no valid
response — the resolver was busy, slow, or the forwarding path dropped the packet.
Node.js surfaces this as `EAI_AGAIN` instead of retrying silently.

It is NOT a permanent failure. The same query may succeed a second later, which is why
the error appears intermittently.

## Why does it happen in Docker Desktop / WSL2?

Docker containers use an embedded DNS resolver at `127.0.0.11`. On Docker Desktop for
Windows (WSL2 backend), external DNS queries are forwarded from the WSL2 VM to the
Windows host through a virtual bridge (`192.168.65.7`). This path is fragile:

- The WSL2 bridge can drop packets under load or after waking from sleep.
- Windows DNS settings change when VPN connects or disconnects.
- Docker's embedded resolver has short timeouts and doesn't retry aggressively.
- The `internal: true` Docker network blocks ALL outbound traffic for services only
  attached to it — including workers that need to call external APIs.

## What was changed

### `compose.yml`
Added a top-level YAML anchor with explicit DNS servers:
```yaml
x-dns: &dns-public
  dns:
    - 1.1.1.1   # Cloudflare
    - 8.8.8.8   # Google
```
Applied to the `n8n` service via `<<: *dns-public`.

Containers with explicit DNS bypass `127.0.0.11` for external queries. Traffic goes
directly to Cloudflare/Google DNS through the `public` bridge network.
Internal names (`postgres`, `redis`, etc.) still resolve via Docker's embedded DNS
because Docker injects its resolver first for internal service discovery.

### `compose.queue.yml`
Two changes to `n8n-worker`:

1. **Added `dns` block** — same servers as above.
2. **Added `public` network** — critical: without it, workers live only on the `internal`
   network (`internal: true`), which blocks ALL outbound traffic. Workflows that call
   external APIs (OpenAI, Anthropic, etc.) will always fail on the worker.

## How to apply the fix

Force-recreate only n8n and n8n-worker (no downtime for postgres, caddy, tunnel):
```powershell
docker compose -f compose.yml -f compose.local.yml -f compose.queue.yml --profile queue up -d --force-recreate n8n n8n-worker
```

Or full restart if needed:
```powershell
docker compose -f compose.yml -f compose.local.yml -f compose.queue.yml --profile queue down
docker compose -f compose.yml -f compose.local.yml -f compose.queue.yml --profile queue up -d
```

## Diagnostic script

```powershell
.\scripts\check-n8n-dns.ps1
```

### Expected output (everything working)

```
=== Container: n8n-app ===
  dns api.openai.com ... 104.18.x.x:IPv4
  dns google.com ... 142.250.x.x:IPv4
  https api.openai.com/v1/models ... HTTP 401 (correct — OpenAI reached, no API key sent)

=== Container: n8n-worker ===
  dns api.openai.com ... 104.18.x.x:IPv4
  dns google.com ... 142.250.x.x:IPv4
  https api.openai.com/v1/models ... HTTP 401 (correct — OpenAI reached, no API key sent)

=== Summary ===
  n8n-app    : OK
  n8n-worker : OK

All checks passed.
```

**HTTP 401 is correct.** It means the container reached OpenAI's servers. OpenAI rejects
the request because no API key was included. Once your workflow sends the key in the
`Authorization: Bearer <key>` header, the call will succeed.

**DNS FAIL or HTTPS FAIL** means the container still cannot reach external hosts.
Check that the `public` network is attached and the containers were recreated (not just
restarted) after the compose changes.
