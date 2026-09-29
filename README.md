# 源时 (SourceTime)

**开源鸿蒙 TOTP 动态口令工具｜本地离线优先｜WebDAV 端到端加密同步**

✨ **源** = 开源、数据本源 ✨ **时** = 基于时间 TOTP 算法

源时是一款**纯本地优先、完全开源**的 HarmonyOS Natively 开发的 TOTP 二因素身份验证器。核心功能只有两个：**TOTP 验证码管理** 与 **WebDAV 加密备份同步**。不联网收集隐私、不上传第三方云端，除必要的系统能力外不依赖云服务、不建立用户账号体系，所有凭据由用户自主掌控。

---

## 📌 项目特色

- **离线优先 · 本地运算**
  查看、新增、删除验证码，修改加密密钥、复制验证码，全部无需联网，断网也能正常使用；WebDAV 仅作为同步与备份能力。

- **全程加密 · 隐私可控**
  TOTP Secret 属于高敏感数据，本地一律经用户密钥加密后存储，绝不出现明文持久化、明文日志或明文上传。

- **用户掌控加密密钥**
  应用不内置固定主密钥，密钥由用户手动输入或一键随机生成（256-bit），生成后支持一键复制，可随时修改。

- **WebDAV 私有云同步**
  支持用户自建 WebDAV 服务器备份，**同步文件先加密再上传**，服务端永远只看到密文（`totp.db.enc`）。

- **完全开源 · 透明可信**
  代码完全开源、无暗门、无统计、无埋点，安全可审计，拒绝闭源黑盒。

- **轻量简洁 · 原生鸿蒙**
  基于 HarmonyOS NEXT 原生开发（ArkTS / ArkUI），极简卡片式首页，体积小、功耗低，适配手机、平板、折叠屏设备。

---

## 🛠 核心功能

- ✅ 扫码录入（解析 `otpauth://totp/...` 二维码，确认后保存）
- ✅ 手动录入（发行方、账号、密钥、算法、位数、周期）
- ✅ 标准 TOTP 动态口令生成（RFC 6238，兼容全网 2FA 服务）
- ✅ 支持 SHA1 / SHA256 / SHA512，6 位 / 8 位，默认周期 30 秒
- ✅ 实时倒计时，点击验证码即复制，长按 / 左滑 / 菜单删除
- ✅ 本地加密单文件存储（`totp.db.enc`）
- ✅ 用户加密密钥：手动输入、随机生成、一键复制、修改
- ✅ 首次启动隐私政策弹窗，同意后方可进入
- ✅ WebDAV 配置、测试连接、手动 Push / Pull
- ✅ 新增 / 删除后自动 Push，启动时自动 Pull（可关闭）
- ✅ 同步队列防并发竞争，V1 冲突策略 Last Write Wins
- ✅ 离线可用，无常驻后台、无隐私上传

V1 暂不实现：HOTP、密码管理、用户账号体系、自建云服务、分类标签、多文件同步、多版本历史、自动合并冲突、浏览器插件。

---

## 🔒 安全设计理念

市面上多数验证器要么强制厂商云同步、要么明文备份、要么闭源无法审计。

**源时 坚持三条安全原则：**

1. **本地为本**：原始凭据只存在用户本机，云端仅存加密副本；本地数据永远是第一优先级，同步失败绝不回滚本地操作
2. **自主可控**：同步服务器由用户自己搭建、自己管理
3. **全程密文**：备份、传输、存储全程加密，无裸数据暴露

**加密方案：**

```text
用户输入字符串 / 系统安全随机数（256-bit）
        ↓
PBKDF2-HMAC-SHA256（随机 16 Bytes Salt）
        ↓
AES-256-GCM（随机 IV，校验 Authentication Tag）
        ↓
加密单文件 totp.db.enc
```

强制安全要求：使用系统安全随机数、随机 Salt、随机 Nonce/IV、必须验证 Authentication Tag；禁止 ECB、无认证的 CBC、自行设计密码学算法、内置默认加密密钥、明文写入文件/Preferences/日志、明文上传 WebDAV。

> 源时不会保存明文加密密钥，也不提供服务器端找回功能。若忘记或丢失密钥，已加密数据可能无法恢复，请务必妥善备份。

---

## 🚀 首次启动流程

```text
启动应用
   ↓
隐私政策弹窗（不同意 → 退出；同意并继续）
   ↓
加密密钥初始化（保护你的数据：输入 / 生成 / 复制密钥）
   ↓
首页（验证码列表）
```

隐私政策确认与加密密钥初始化是首次使用流程的一部分，不得绕过；隐私政策版本重大升级时会重新要求确认。

---

## 🧩 技术栈（V1 技术决策）

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
| 开源协议 | MIT / Apache-2.0 二选一 |

架构分层：

```text
Page → ViewModel → Service → Storage / Crypto / WebDAV
```

页面不直接访问文件、Crypto API、WebDAV 与 TOTP 核心算法。

---

## 📁 项目目录

```text
entry/src/main/ets/
├── pages/        HomePage / AddTotpPage / ScanPage / SettingsPage / SecurityPage / WebDavPage / PrivacyPolicyPage / AboutPage
├── components/   TotpCard / CountDown / SecretInput / PrivacyDialog / EmptyState
├── model/        TotpItem / DatabaseModel / WebDavConfig / Settings
├── service/      TotpService / OtpParser / CryptoService / StorageService / SyncService / WebDavService / ClipboardService
├── viewmodel/    HomeViewModel / AddTotpViewModel / SecurityViewModel / SettingsViewModel
└── utils/        Base32 / Time / UUID / Logger
```

---

## 📥 下载安装

目前支持鸿蒙原生安装，后续上架华为应用市场。

正式版、测试版、更新日志请关注本仓库 Release。

---

## 💡 使用场景

- 网站、后台、服务器、Git 平台、社交账号 2FA 二次验证
- 追求透明、安全、自主可控的用户
- 需要多设备同步，但不想把密钥交给第三方云厂商的用户

---

## 📄 开源协议

本项目 MIT 开放，欢迎学习、使用、提交 PR、Issue。
使用、二次分发请遵守开源协议，保留项目开源声明。

---

## 🌟 致谢

如果项目对你有帮助，欢迎 Star、Fork、支持作者持续维护！
