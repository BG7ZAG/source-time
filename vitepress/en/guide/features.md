# Features

SourceTime has two core capabilities: **TOTP code management** and **encrypted WebDAV backup sync**. Below is what V1 delivers.

## Code management

- ✅ QR-code enrollment (parse `otpauth://totp/...`, confirm and save)
- ✅ Manual entry (issuer, account, secret, algorithm, digits, period)
- ✅ Standard TOTP generation (RFC 6238, compatible with mainstream 2FA services)
- ✅ SHA1 / SHA256 / SHA512, 6 or 8 digits, 30-second period by default
- ✅ Live countdown; tap a code to copy; long-press / swipe-left / menu to delete
- ✅ Encrypted single-file local storage (`totp.db.enc`)

## Security capabilities

- ✅ Encryption key: enter manually, generate randomly, copy with one tap, rotate
- ✅ Privacy-policy dialog on first launch; entry only after consent (a policy bump re-prompts)
- ✅ PIN app lock: locks automatically when backgrounded, unlock required to view codes
- ✅ Log viewer: on-device diagnostics with secrets and codes redacted before writing to disk

## Sync capabilities

- ✅ WebDAV config, connection test, manual Push / Pull (sync directories are created recursively)
- ✅ Auto Push after add / delete, auto Pull on launch (both toggleable)
- ✅ A sync queue prevents concurrent races; V1 conflict policy is Last Write Wins

## Interactions

### Code card

The home screen lists codes as cards showing the issuer, account and current code, with a countdown ring. Tapping the code copies it.

### Countdown

The default period is 30 seconds. Codes refresh before expiry, and the countdown ring shifts color as it approaches the end.

### Delete

Delete an entry by **long-pressing** a card, **swiping left**, or through the **card menu**. Deletion triggers a sync per your settings.

## Not in V1

HOTP, password management, user accounts, self-hosted cloud services, category tags, multi-file sync, multi-version history, automatic conflict merge, and browser extensions.

---

Continue with: [WebDAV Sync](/en/guide/webdav-sync) ｜ [Security](/en/guide/security)