# 技术栈与架构

## 技术栈（V1 技术决策）

| 项目 | 决策 |
|---|---|
| 平台 | HarmonyOS NEXT |
| 开发语言 | ArkTS / ArkUI |
| TOTP | RFC 6238 |
| Hash | SHA1 / SHA256 / SHA512 |
| OTP 位数 | 6 / 8 |
| 默认周期 | 30 秒 |
| 加密 | AES-256-GCM |
| KDF | PBKDF2-HMAC-SHA256 |
| 随机密钥 | 256-bit |
| 本地格式 | 加密 JSON 单文件 `totp.db.enc` |
| WebDAV | GET / PUT / PROPFIND |
| 同步模式 | Offline First |
| 冲突策略 | V1 Last Write Wins |
| 密钥保管 | Asset Store Kit（DEVICE_UNLOCKED 档）+ 可选 PIN 应用锁 |
| 传输 | WebDAV 默认强制 https，明文 http 需用户在设置中显式开启 |
| 发布构建 | 代码混淆（顶层名 + 文件名；属性名混淆关闭以保持既有密文兼容） |
| 开源协议 | MIT（见 `LICENSE`） |

## 架构分层

```text
Page → ViewModel → Service → Storage / Crypto / WebDAV
```

- **UI 不实现业务逻辑**：页面不直接访问文件、Crypto API、WebDAV 与 TOTP 核心算法。
- **统一返回约定**：以 `success + code + message` 的结果类型贯穿各层。

## 项目目录

```text
entry/src/main/ets/
├── pages/            HomePage / ScanPage / SettingsPage / SecurityPage / WebDavPage / PrivacyPolicyPage / AboutPage / LogPage
├── components/       AuroraBackground / TotpCard / CountDown / AddTotpSheet / BackupPickerDialog / PinLockOverlay / PrivacyDialog / EmptyState
├── viewmodel/        HomeViewModel / AddTotpViewModel
├── service/          TotpService / OtpParser / CryptoService / StorageService / SettingsService / SyncService / WebDavService / KeyStoreService / PinService / ClipboardService / LogStore
├── repository/       LocalRepository（本地加密文件读写）
├── model/            TotpItem / DatabaseModel / WebDavConfig / SettingsModel / SyncModel / LogEntry / RemoteBackup
├── constants/        AppConstants / CryptoConstants / SyncConstants
├── theme/            GlassStyle（冰晶视觉：颜色、阴影、渐变与倒计时状态）
├── types/            Result / Errors（统一的 success + code + message 返回约定）
├── utils/            Base32Utils / TimeUtils / UUIDUtils / Logger / Sanitizer / ColorUtils / AppContextHolder
├── entryability/         EntryAbility（窗口与安全区、冷启动自动同步、前后台上锁）
└── entrybackupability/   EntryBackupAbility（系统备份恢复入口，当前已在配置中关闭）
```

## 文档站目录

本 VitePress 文档站位于仓库根目录下的 `vitepress/`：

```text
vitepress/
├── .vitepress/
│   ├── config.mts        站点配置（导航、侧边栏、搜索、SEO）
│   └── theme/
│       ├── index.ts      自定义主题入口
│       └── custom.css    品牌主色与视觉基调
├── guide/                指南文档
│   ├── introduction.md
│   ├── getting-started.md
│   ├── features.md
│   ├── webdav-sync.md
│   ├── security.md
│   ├── architecture.md
│   └── faq.md
├── index.md              站点首页
├── package.json          依赖与脚本
└── .gitignore
```

## 核心模块职责

| 模块 | 职责 |
|---|---|
| `TotpService` | TOTP 口令计算、倒计时计算 |
| `OtpParser` | 解析 `otpauth://totp/...` URI 与二维码 |
| `CryptoService` | 密钥派生、加解密、随机密钥生成 |
| `StorageService` | 加密文件的原子读写 |
| `WebDavService` | WebDAV HTTP 方法封装 |
| `SyncService` | Push / Pull 流程、同步队列与冲突策略 |
| `KeyStoreService` | 密钥保管（Asset Store Kit） |
| `PinService` | PIN 应用锁 |
| `ClipboardService` | 口令复制与剪贴板安全 |
| `LogStore` | 运行日志与脱敏 |

---

继续了解：[常见问题](/guide/faq)