# WebDAV Sync

WebDAV provides SourceTime's **private-cloud sync and backup**: files are **encrypted before upload**, so the server only ever sees ciphertext. You can use a self-hosted WebDAV server and keep full control of your data.

## Design notes

- Cloud filenames look like `sourcetime-20261014-154512.enc`; **every push creates a timestamped snapshot and never overwrites history**.
- The server stores only AES-256-GCM ciphertext and cannot decrypt it.
- Sync files **do not contain the WebDAV configuration**; WebDAV config and TOTP data are stored separately.
- Transport defaults to `https`; plaintext `http` must be explicitly enabled in settings.

## Configure WebDAV

On the "WebDAV" page fill in:

| Field | Description |
|---|---|
| Server URL | Your WebDAV root URL (`https://` recommended) |
| Username | WebDAV account |
| Password | WebDAV password (stored securely locally; never written into sync files) |
| Sync directory | Directory holding encrypted backups; created recursively if missing |

Use "Test connection" to verify the configuration.

::: warning Security note
The WebDAV password is stored separately from TOTP data and never enters sync files. Use a dedicated, least-privilege WebDAV account.
:::

## Manual sync

- **Push (upload)**: upload the local encrypted database as a timestamped encrypted snapshot.
- **Pull (download)**: fetch the latest encrypted snapshot from the cloud and merge it into local data after decryption.

## Auto-sync policy

- **Auto Push**: after adding / deleting a code (toggleable).
- **Auto Pull**: on app launch (toggleable).
- A failed auto-sync never rolls back local operations; local data always stays the top priority.

## Concurrency & conflicts

- **Sync queue**: Push / Pull run serially through a queue to avoid concurrent races.
- **Conflict policy (V1)**: Last Write Wins.
- **Revision rule**: revision numbers determine which side is newer, avoiding accidental overwrites.

## Sync file structure

```text
sourcetime-YYYYMMDD-HHMMSS.enc
└── AES-256-GCM ciphertext (containing an encrypted database snapshot)
```

## Failures & retries

- Auto-sync failures surface clear status feedback without blocking local use.
- Manual retries are supported; Push / Pull can be run again once the network recovers.

## HTTP status handling

| Status | Handling |
|---|---|
| 2xx | Success |
| 401 / 403 | Auth failure; prompt to check account or permissions |
| 404 | Try to create the directory automatically when missing |
| Other | Log and notify the user |

---

Continue with: [Security](/en/guide/security) ｜ [FAQ](/en/guide/faq)