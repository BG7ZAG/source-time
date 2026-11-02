---
layout: home

hero:
  name: SourceTime
  text: 源时
  tagline: A HarmonyOS TOTP authenticator · Local-first · End-to-end encrypted WebDAV sync
  actions:
    - theme: brand
      text: Quick Start
      link: /en/guide/getting-started
    - theme: alt
      text: Introduction
      link: /en/guide/introduction

features:
  - icon: 🔐
    title: Local-first · On-device
    details: Viewing, adding and deleting codes, and changing the encryption key all work without a network connection. WebDAV is only a sync and backup capability — the network is never a core dependency.
  - icon: 🛡️
    title: Fully Encrypted · Private
    details: TOTP secrets are highly sensitive. Locally they are always stored encrypted with your own key — never plaintext on disk, in logs, or in transit.
  - icon: 🔑
    title: You Own the Key
    details: No hardcoded master key. The key is entered manually by you or generated at 256-bit randomness, and can be rotated or copied at any time.
  - icon: ☁️
    title: Private WebDAV Sync
    details: Back up to your own WebDAV server. Files are encrypted before upload, so the server only ever sees ciphertext, and every push creates a timestamped snapshot.
  - icon: 📖
    title: Fully Open Source · Auditable
    details: No backdoors, no analytics, no tracking. Security you can audit, released under the MIT License.
  - icon: ⚡
    title: Lightweight · Native HarmonyOS
    details: Built natively for HarmonyOS NEXT (ArkTS / ArkUI) with a minimal card-based UI. Small, power-efficient, and adaptive to phones, tablets and foldables.
---