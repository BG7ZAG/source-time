# FAQ

## Does SourceTime upload my keys to the cloud?

No. SourceTime never uploads to third-party clouds and has no user accounts. WebDAV sync encrypts data locally first, and the server stores only AES-256-GCM ciphertext it cannot decrypt.

## What if I forget the encryption key?

SourceTime never stores the plaintext key and offers no server-side recovery. **If you forget or lose the key, encrypted data may be unrecoverable.** Save the key securely right after generating it.

## Does it work offline?

Yes. SourceTime is local-first: viewing, adding and deleting codes, rotating the key and copying codes all work without a network. WebDAV is only a sync and backup capability.

## Which TOTP parameters are supported?

- Algorithms: SHA1 / SHA256 / SHA512
- Digits: 6 / 8
- Period: 30 seconds by default
- Protocol: RFC 6238, compatible with mainstream 2FA services

## How do I import existing codes?

- **Scan**: scan the other party's `otpauth://totp/...` QR code and confirm.
- **Manual**: fill in issuer, account, secret, algorithm, digits and period.

## Will cloud backups overwrite previous data?

No. Every push creates a timestamped snapshot file (e.g. `sourcetime-20261014-154512.enc`) and **never overwrites history**.

## How are sync conflicts handled?

V1 uses **Last Write Wins**. Push / Pull run serially through a sync queue to avoid concurrent races.

## Can WebDAV use http?

It defaults to `https`. Plaintext `http` can be explicitly enabled in settings when truly necessary.

## Which devices are supported?

Phones, tablets and foldables, built natively for HarmonyOS NEXT (ArkTS / ArkUI).

## How do I preview this documentation site locally?

```bash
cd vitepress
npm install
npm run dev
```

The build output goes to `vitepress/.vitepress/dist`.

## What is missing in V1?

HOTP, password management, user accounts, self-hosted cloud services, category tags, multi-file sync, multi-version history, automatic conflict merge, and browser extensions.

---

Have more questions? Open an Issue or PR in the repository.