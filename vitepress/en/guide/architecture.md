# Tech Stack & Architecture

## Tech stack (V1 decisions)

| Item | Decision |
|---|---|
| Platform | HarmonyOS NEXT |
| Language | ArkTS / ArkUI |
| TOTP | RFC 6238 |
| Hash | SHA1 / SHA256 / SHA512 |
| OTP digits | 6 / 8 |
| Default period | 30 seconds |
| Encryption | AES-256-GCM |
| KDF | PBKDF2-HMAC-SHA256 |
| Random key | 256-bit |
| Local format | Encrypted JSON single file `totp.db.enc` |
| WebDAV | GET / PUT / PROPFIND |
| Sync mode | Offline First |
| Conflict policy | V1 Last Write Wins |
| Key custody | Asset Store Kit (DEVICE_UNLOCKED class) + optional PIN app lock |
| Transport | WebDAV defaults to https; plaintext http requires explicit opt-in in settings |
| Release build | Code obfuscation (top-level names + file names; property-name obfuscation disabled to keep existing ciphertext compatible) |
| License | MIT (see `LICENSE`) |

## Layered architecture

```text
Page → ViewModel → Service → Storage / Crypto / WebDAV
```

- **UI holds no business logic**: pages never touch files, the Crypto API, WebDAV, or the TOTP core directly.
- **Unified return contract**: a `success + code + message` result type runs through every layer.

## Project layout

```text
entry/src/main/ets/
├── pages/            HomePage / ScanPage / SettingsPage / SecurityPage / WebDavPage / PrivacyPolicyPage / AboutPage / LogPage
├── components/       AuroraBackground / TotpCard / CountDown / AddTotpSheet / BackupPickerDialog / PinLockOverlay / PrivacyDialog / EmptyState
├── viewmodel/        HomeViewModel / AddTotpViewModel
├── service/          TotpService / OtpParser / CryptoService / StorageService / SettingsService / SyncService / WebDavService / KeyStoreService / PinService / ClipboardService / LogStore
├── repository/       LocalRepository（encrypted local file I/O）
├── model/            TotpItem / DatabaseModel / WebDavConfig / SettingsModel / SyncModel / LogEntry / RemoteBackup
├── constants/        AppConstants / CryptoConstants / SyncConstants
├── theme/            GlassStyle（frosted visual: colors, shadows, gradients, countdown states）
├── types/            Result / Errors（unified success + code + message contract）
├── utils/            Base32Utils / TimeUtils / UUIDUtils / Logger / Sanitizer / ColorUtils / AppContextHolder
├── entryability/         EntryAbility（window & safe area, cold-start auto-sync, foreground/background lock）
└── entrybackupability/   EntryBackupAbility（system backup restore entry, currently disabled in config）
```

## Docs site layout

This VitePress site lives in `vitepress/` at the repository root:

```text
vitepress/
├── .vitepress/
│   ├── config.mts        Site config (i18n, nav, sidebar, search, SEO)
│   └── theme/
│       ├── index.ts      Custom theme entry
│       └── custom.css    Brand color and visual tone
├── guide/                Chinese guide
│   ├── introduction.md
│   ├── getting-started.md
│   ├── features.md
│   ├── webdav-sync.md
│   ├── security.md
│   ├── architecture.md
│   └── faq.md
├── en/                   English site
│   ├── index.md
│   └── guide/            (mirrors the Chinese pages)
├── index.md              Home page (Chinese, default)
├── public/logo.svg       App logo
├── package.json          Dependencies and scripts
└── .gitignore
```

## Core module responsibilities

| Module | Responsibility |
|---|---|
| `TotpService` | TOTP generation, countdown calculation |
| `OtpParser` | Parse `otpauth://totp/...` URIs and QR codes |
| `CryptoService` | Key derivation, encryption/decryption, random key generation |
| `StorageService` | Atomic reads and writes of the encrypted file |
| `WebDavService` | WebDAV HTTP method wrapper |
| `SyncService` | Push / Pull flows, sync queue and conflict policy |
| `KeyStoreService` | Key custody (Asset Store Kit) |
| `PinService` | PIN app lock |
| `ClipboardService` | Code copy and clipboard security |
| `LogStore` | Runtime logs and redaction |

---

Continue with: [FAQ](/en/guide/faq)