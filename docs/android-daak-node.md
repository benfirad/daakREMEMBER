# Android integration with DAAK NODE

DAAK NODE can use a Mac running daakREMEMBER as the private source of truth for
notes and tasks. The Android launcher reads the current snapshot and can append
new items without a cloud account or a public server.

## Data flow

1. daakREMEMBER listens on TCP port `45831` on the Mac.
2. DAAK NODE requests `GET /snapshot` to show current items.
3. A confirmed Android capture is sent as a `POST /merge` sync envelope.
4. If the Mac is unavailable, DAAK NODE keeps an on-device retry queue.
5. The launcher can also export a one-way Markdown mirror to the local Obsidian
   vault. daakREMEMBER remains the authoritative task store.

DAAK NODE's dictation inbox always asks the user to choose daakREMEMBER,
Obsidian, both destinations, or a Codex CLI session before writing anything.
WhatsApp notification capture is limited to task-like phrases and never sends a
message.

## Setup

- Install Tailscale on the Mac and Android device and sign both into the same
  tailnet.
- Keep daakREMEMBER running on the Mac.
- Set `remember_host` in DAAK NODE's local `config.properties` to the Mac's
  MagicDNS name or Tailscale IP.
- Open DAAK NODE's REMEMBER panel and refresh. New Android entries should appear
  on the Mac immediately when it is online.

## Security

The service rejects connections unless the source is within Tailscale's IPv4
`100.64.0.0/10` or IPv6 `fd7a:115c:a1e0::/48` ranges. Tailscale provides the
encrypted transport and identity layer; port `45831` must not be forwarded from
the public internet. DAAK NODE stores no daakREMEMBER password because the
service is intentionally tailnet-only.

The protocol is a small JSON snapshot/merge API intended for trusted personal
devices on one tailnet. Use Tailscale ACLs or grants if the tailnet includes
devices that should not read the notebook.
