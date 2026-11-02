# Introduction

**SourceTime (源时)** is a **fully local-first, completely open-source** TOTP two-factor authenticator built natively for HarmonyOS.

> ✨ **源** = open source, the origin of your data ｜ ✨ **时** = time-based TOTP algorithm

It has exactly two core capabilities: **TOTP code management** and **encrypted WebDAV backup sync**. It never collects your data over the network, never uploads to third-party clouds, and — apart from the necessary system capabilities — relies on no cloud services and no user accounts. All credentials stay under your control.

## Why SourceTime

Most authenticators either force vendor cloud sync, store backups in plaintext, or are closed-source and unauditable. SourceTime upholds three security principles:

1. **Local-first**: Raw credentials live only on your device; the cloud holds only encrypted copies. Local data always comes first, and a failed sync never rolls back local operations.
2. **Self-sovereign**: You host and manage your own sync server.
3. **Always ciphertext**: Backup, transit and storage are encrypted end to end, with no raw data exposure.

## Highlights

- **Local-first · On-device**
  View, add and delete codes, rotate the encryption key, or copy a code — all without a network connection. WebDAV is only a sync and backup capability.

- **Fully encrypted · Private**
  TOTP secrets are highly sensitive and are always stored encrypted with your key locally — never plaintext on disk, in logs, or in transit.

- **You own the encryption key**
  No hardcoded master key. The key is entered manually or generated at 256-bit randomness, can be copied with one tap, and rotated at any time.

- **Private WebDAV sync**
  Back up to your own WebDAV server. **Files are encrypted before upload**, so the server only sees ciphertext (filenames look like `sourcetime-20261014-154512.enc`; each push produces a timestamped snapshot and never overwrites history).

- **Fully open source · Auditable**
  No backdoors, no analytics, no tracking. Security you can audit — no closed black boxes.

- **Lightweight · Native HarmonyOS**
  Built natively for HarmonyOS NEXT (ArkTS / ArkUI) with a minimal card-based home screen. Small, power-efficient, and adaptive to phones, tablets and foldables.

## Use cases

- Two-factor authentication for websites, admin panels, servers, Git platforms and social accounts
- Users who value transparency, security and self-sovereignty
- Users who want multi-device sync without handing keys to a third-party cloud provider

## Scope of V1

Not implemented in V1: HOTP, password management, user accounts, self-hosted cloud services, category tags, multi-file sync, multi-version history, automatic conflict merge, and browser extensions.

---

Next: read [Quick Start](/en/guide/getting-started) to get going, or see [Features](/en/guide/features).