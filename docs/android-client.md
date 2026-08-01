# Android support with DAAK NODE

DAAK NODE is the supported Android companion for daakREMEMBER. It talks to the
existing TailSync service over TCP 45831 and keeps the Mac as the canonical
store. The Android client can:

- read active notes from `GET /snapshot`;
- add a note by merging the updated item set through `POST /merge`;
- queue a note locally while the Mac is offline and retry later;
- turn explicit task-like WhatsApp notification text into a pending note when
  the user leaves that automation enabled.

## Network and privacy model

Both devices must be on the same private Tailscale network. TailSync rejects
connections whose source address is outside Tailscale's IPv4 and IPv6 ranges.
Do not forward port 45831 from a router and do not publish it through a public
reverse proxy.

The Android launcher contains no Tailnet address, password, SSH key or API key.
Host names are loaded from a local `config.properties` file. WhatsApp support
uses only notification text already displayed by Android, stores at most a
small recent task list, and cannot send or modify messages.

## DAAK NODE setup

1. Install and sign in to Tailscale on Android and the Mac.
2. Keep daakREMEMBER running on the Mac.
3. Create `/sdcard/Download/daak-node/config.properties` on Android:

   ```properties
   mac_host=your-mac.tailnet.example
   remember_host=your-mac.tailnet.example
   ```

4. Open **REMEM** on the DAAK NODE home screen to view or capture a note.

The legacy `/sdcard/Download/firat-node/config.properties` location remains a
compatibility fallback for existing installations.
