# Quick Start

## Requirements

- Platform: HarmonyOS NEXT
- Language: ArkTS / ArkUI
- Toolchain: DevEco Studio + hvigor

## Get & Install

<p align="center">
  <a href="https://url.cloud.huawei.com/D0D1qLBUbK" target="_blank" rel="noreferrer">
    <img src="/badges/appgallery-badge-en.png" alt="Get SourceTime on AppGallery" height="52">
  </a>
</p>

- **AppGallery**: tap the badge above, or open the [SourceTime listing](https://url.cloud.huawei.com/D0D1qLBUbK)
- **Native HarmonyOS sideload**: build `entry-default-signed.hap` yourself and install it

Releases are published on AppGallery; this repository does not ship a Release package.

## First launch flow

```text
Launch app
   ↓
Privacy policy dialog (decline → exit; accept & continue)
   ↓
Encryption key setup (protect your data: enter / generate / copy key)
   ↓
Home screen (code list)
```

Privacy-policy confirmation and encryption-key setup are part of the first-run flow and **must not be bypassed**; a major privacy-policy version bump will prompt for confirmation again.

## Encryption key setup

On first launch you enter the "Protect your data" flow, where you can:

- **Enter manually**: use a passphrase you can remember as the encryption key
- **Generate randomly**: create a 256-bit system-secure key with one tap
- **Copy with one tap**: copy and keep the generated key safe

> SourceTime never stores the plaintext encryption key and offers no server-side recovery. If you forget or lose the key, encrypted data may be unrecoverable — back it up carefully.

::: tip Tip
The key is the only credential that decrypts your local data and cloud backups. Save it to a password manager or an offline record right after generating it.
:::

## Add a code

From the home screen you can add TOTP entries in two ways:

- **Scan a QR code**: parse an `otpauth://totp/...` QR code and save after confirming
- **Enter manually**: fill in issuer, account, secret, algorithm, digits and period

## Build this documentation site

This directory is itself a VitePress site. Local commands:

```bash
# Enter the docs site directory
cd vitepress

# Install dependencies
npm install

# Local preview (http://localhost:5173 by default)
npm run dev

# Build the static site into .vitepress/dist
npm run build

# Preview the build output
npm run preview
```

## Next steps

- [Features](/en/guide/features): code management and interactions
- [WebDAV Sync](/en/guide/webdav-sync): configure your own private-cloud sync
- [Security](/en/guide/security): the encryption scheme and security boundaries
