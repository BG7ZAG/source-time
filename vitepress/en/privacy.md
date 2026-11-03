---
title: Privacy Policy
---

# SourceTime Privacy Policy

**Version: 2.3**
**Effective date: October 16, 2026**
**Product: SourceTime for HarmonyOS**

SourceTime is a local-first TOTP authenticator for HarmonyOS. We take your privacy seriously. This policy explains what information the App processes and how you can exercise your rights.

## 1. Scope

1. The App generates one-time codes locally on your device following RFC 6238.
2. This policy covers all data processing in the App, including collection, encrypted local storage, runtime logs, WebDAV sync, clipboard use and data deletion.
3. This policy covers the App only. WebDAV servers you configure, and system capabilities such as the clipboard and camera, are governed by their own providers or the operating system.
4. The App is open source under the MIT License. You can review the source code to verify these statements.

## 2. What We Process

**The App does not collect or upload personal information, and requires no registration or login.**

It processes the following information locally, only when you provide it:

| Information | Purpose | Leaves the device? |
|-------------|---------|-------------------|
| Issuer, account, TOTP secret | Generate codes locally | No |
| Encryption key | Encrypt credential data (AES-256-GCM) | No (kept in system secure storage) |
| Derived app-lock PIN verifier | Verify the app lock; the PIN itself is never stored | No |
| WebDAV server address, username, password | Access your server when you enable sync | Only to the server you specify |
| Runtime logs | Troubleshooting; redacted before writing | No |

We do not perform profiling, targeted marketing or behavioral analytics.

## 3. Permissions

| Permission | Purpose | When requested |
|------------|---------|----------------|
| Camera | Scan otpauth QR codes | When you tap "Scan QR code" |
| Network | Access your WebDAV server | When you enable and run sync |
| Distributed data sync | Sync WebDAV settings to your watch on the same account | When you tap "Sync to watch" |
| Privacy window | Prevent screenshots and screen recording | While the App is running |
| Clipboard | Write a code when you tap "Copy" | When you tap copy |

Denying these permissions does not affect local code generation.

## 4. Storage and Security

1. TOTP data is encrypted with AES-256-GCM. The encryption key is derived with PBKDF2-HMAC-SHA256 (100,000 iterations) and kept in system secure storage.
2. The App does not participate in system backup (`allowToBackupRestore=false`); data does not leave the device through backups.
3. The app lock stores only a derived verifier, never the PIN in plaintext.
4. Runtime logs stay in the app sandbox and are never uploaded; secrets and passwords are redacted before being written or displayed.

## 5. Sharing and Transfer

1. We do not upload, share or transfer your data to the developer or any third party.
2. With WebDAV enabled, only **encrypted files** are uploaded to the server you specify; the server sees ciphertext only.
3. Only HTTPS addresses are allowed by default. If you explicitly enable "Allow insecure connections", credentials and ciphertext are transmitted without TLS protection, at your own risk.
4. The developer does not operate any server that receives your data.

## 6. Your Rights

| Right | How to exercise |
|-------|-----------------|
| Access | View codes on the home page; view settings under Settings → Security & key and WebDAV sync |
| Correction | Long-press a code card → Rename; edit server settings under Settings → WebDAV sync |
| Deletion | Swipe a code card left → Delete; or uninstall the App / clear app data |
| Withdraw consent | Disable WebDAV sync or the app lock; or uninstall the App |
| Account deletion | The App has no account system, so deletion is not applicable |

## 7. Minors

The App is not offered to minors as a standalone service and does not collect age or identity information. Minors should use it under the guidance of a guardian.

## 8. Policy Updates

This policy may be updated as features or regulations change. Updates will be published on this page with a new version and effective date. Material changes will be announced in the App.

## 9. Contact Us

If you have questions, comments or suggestions about this policy, contact us via:

- Repository: [BG7ZAG/source-time](https://github.com/BG7ZAG/source-time)
- Feedback: open an issue in the repository

We will respond as soon as possible.