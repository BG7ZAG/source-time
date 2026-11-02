# Security

SourceTime puts "data origin, user control" first. This page covers the encryption scheme, security boundaries and mandatory requirements.

## Three security principles

1. **Local-first**: Raw credentials live only on your device; the cloud holds only encrypted copies. Local data always comes first, and a failed sync never rolls back local operations.
2. **Self-sovereign**: You host and manage your own sync server.
3. **Always ciphertext**: Backup, transit and storage are encrypted end to end, with no raw data exposure.

## Encryption scheme

```text
User-entered string / system-secure random (256-bit)
        ↓
PBKDF2-HMAC-SHA256 (random 16-byte salt)
        ↓
AES-256-GCM (random IV, authenticated tag verified)
        ↓
Encrypted single file totp.db.enc
```

- **KDF**: PBKDF2-HMAC-SHA256 with a random 16-byte salt.
- **Encryption**: AES-256-GCM with a random IV and mandatory authentication-tag verification.
- **Random key**: 256-bit system-secure randomness.
- **Local format**: encrypted JSON single file `totp.db.enc`.

## Key custody

- No hardcoded master key: the key is entered manually or generated at 256-bit randomness.
- Keys are held in **Asset Store Kit (DEVICE_UNLOCKED class)**, optionally combined with a **PIN app lock**.
- SourceTime **never stores the plaintext key** and offers no server-side recovery.

::: danger Back up your key
If you forget or lose the encryption key, encrypted data may be unrecoverable. The key is the only credential that decrypts your local data and cloud backups.
:::

## Mandatory security requirements

**Must:**

- Use system-secure randomness, random salt, and random nonce / IV.
- Verify the authentication tag.
- Default to `https` for transport.

**Forbidden:**

- ECB, or CBC without authentication.
- Bespoke cryptographic algorithms.
- Hardcoded default encryption keys.
- Writing plaintext to files / Preferences / logs.
- Uploading plaintext to WebDAV.

## Handling sensitive data

- **TOTP secret in memory**: sensitive fields live only in the scope they are needed and are cleared afterwards.
- **Log redaction**: secrets and codes are redacted before writing to disk; logs are for on-device diagnostics only.
- **In-memory database policy**: decrypted data does not linger; it is loaded on demand and released after use.

## PIN app lock

- When enabled, the app locks automatically upon backgrounding and requires unlocking to view codes.
- Combined with platform security, it reduces exposure from brief physical access to your device.

## Privacy policy

A privacy-policy dialog appears on first launch and entry requires consent; a major policy version bump re-prompts. The app has no analytics, no tracking and no third-party cloud uploads.

---

Continue with: [Tech Stack & Architecture](/en/guide/architecture) ｜ [FAQ](/en/guide/faq)