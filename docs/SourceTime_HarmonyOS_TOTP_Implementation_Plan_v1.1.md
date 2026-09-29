# 源时（SourceTime）
## HarmonyOS 开源 TOTP 身份验证器实现规划文档

**项目名称：源时（SourceTime）**

**项目定位：**  
一个开源、离线优先、用户自主掌控数据、支持 WebDAV 加密同步的 HarmonyOS TOTP 身份验证器。

核心功能只有两个：

1. **TOTP 验证码管理**
2. **WebDAV 加密备份与同步**

除必要的系统能力外，不依赖第三方云服务，不建立用户账号体系。

---

# 1. 产品目标

源时需要满足以下目标：

- 支持扫描二维码录入 TOTP。
- 支持手动输入 TOTP 信息。
- 实时生成并展示 TOTP 验证码。
- 支持点击复制验证码。
- 支持删除 TOTP。
- 所有 TOTP 数据默认本地加密存储。
- 用户可以自行输入加密密钥。
- 用户可以一键随机生成加密密钥。
- 生成密钥后，可以点击复制按钮复制密钥。
- 支持配置 WebDAV。
- 配置 WebDAV 后，新增和删除 TOTP 默认自动同步。
- 支持手动 Push / Pull。
- 支持应用启动时自动 Pull，可由用户关闭。
- WebDAV 始终只存储加密数据。
- 首次进入应用时展示隐私政策弹窗，用户同意后进入应用。
- 应用本身尽量保持轻量、极简。

---

# 2. 产品原则

## 2.1 离线优先

没有 WebDAV、没有网络也必须能够：

- 查看验证码
- 新增验证码
- 删除验证码
- 修改加密密钥
- 复制验证码

WebDAV 只作为同步和备份能力，不应该影响本地核心功能。

## 2.2 本地数据优先保护

TOTP Secret 属于高敏感数据。

任何情况下都不允许：

- 明文写入持久化文件。
- 明文写入 Preferences。
- 明文上传 WebDAV。
- 写入日志。
- 在异常信息中输出完整 Secret。

## 2.3 用户掌控加密密钥

应用不能内置固定主密钥。

用户可以：

- 手动输入密钥。
- 自动生成随机密钥。
- 复制自动生成的密钥。
- 修改密钥。

---

# 3. MVP 功能范围

| 模块 | 功能 | 优先级 |
|---|---|---:|
| 首次启动 | 隐私政策弹窗 | P0 |
| TOTP | 扫码录入 | P0 |
| TOTP | 手动录入 | P0 |
| TOTP | 验证码生成 | P0 |
| TOTP | 验证码复制 | P0 |
| TOTP | 删除 | P0 |
| 安全 | 用户输入加密密钥 | P0 |
| 安全 | 随机生成加密密钥 | P0 |
| 安全 | 一键复制生成的密钥 | P0 |
| 安全 | 本地加密存储 | P0 |
| WebDAV | 配置 | P0 |
| WebDAV | 测试连接 | P0 |
| WebDAV | 手动 Push | P0 |
| WebDAV | 手动 Pull | P0 |
| WebDAV | 新增后自动 Push | P0 |
| WebDAV | 删除后自动 Push | P0 |
| WebDAV | 启动自动 Pull | P1 |
| 设置 | 自动同步开关 | P0 |
| 设置 | 修改加密密钥 | P1 |
| 设置 | 关于 | P1 |

V1 暂不实现：

- HOTP
- 密码管理
- 用户账号体系
- 自建云服务
- 分类、标签
- 多文件同步
- 多版本历史
- 自动合并冲突
- 浏览器插件

---

# 4. 首次启动流程

首次安装并打开源时时，必须先显示隐私政策弹窗。

流程：

```text
启动应用
   ↓
检查是否已经同意隐私政策
   ↓
否
   ↓
显示隐私政策弹窗
   ↓
用户查看
   ↓
[不同意] → 退出/关闭应用
   ↓
[同意]
   ↓
进入加密密钥初始化
   ↓
进入首页
```

已经同意过隐私政策后，后续启动不再重复弹窗，除非隐私政策版本发生重大变更。

---

# 5. 隐私政策弹窗

## 5.1 展示内容

弹窗标题：

**隐私政策**

建议正文明确说明：

- 源时是一款本地优先的 TOTP 验证器。
- TOTP 数据默认保存在设备本地。
- TOTP 数据经过用户设置的加密密钥加密后存储。
- 如果用户配置 WebDAV，应用会将加密后的数据同步到用户指定的 WebDAV 服务。
- 应用不会主动向开发者服务器上传 TOTP Secret。
- WebDAV 服务由用户自行配置和管理。
- 用户需要自行妥善保管加密密钥。
- 如果丢失加密密钥，应用可能无法恢复已经加密的数据。

按钮：

**不同意**

**同意并继续**

建议在正文中提供：

**《隐私政策》完整内容**

可点击打开独立隐私政策页面。

---

# 6. 加密密钥初始化

隐私政策同意后，进入“设置加密密钥”。

页面标题：

**保护你的数据**

说明：

> 源时会使用你设置的加密密钥保护本地 TOTP 数据。  
> 请妥善保存此密钥，忘记后将无法解密已经加密的数据。

---

## 6.1 输入框

页面包含：

```text
加密密钥
┌──────────────────────────────┐
│ 输入加密密钥          [生成] │
└──────────────────────────────┘
```

右侧提供：

**生成**按钮。

用户可以：

- 手动输入密钥。
- 点击“生成”随机生成安全密钥。

---

# 7. 随机生成加密密钥

点击：

**生成**

应用使用系统安全随机数生成器生成随机密钥。

建议生成：

**32 Bytes / 256 Bits**

为了方便用户保存和复制，可以编码成 Base64 或 Base64URL 字符串展示。

例如：

```text
dY8Y4W8xJ1J7QqT1g7x7kN4x...
```

实际生成必须使用密码学安全随机数，不能使用普通随机函数。

---

# 8. 生成密钥后的 UI

生成后输入框自动填充：

```text
加密密钥

┌──────────────────────────────┐
│ dY8Y4W8xJ1J7...        [复制] │
└──────────────────────────────┘
```

右侧显示：

**复制图标**

点击复制后：

```text
密钥已复制
```

同时建议增加视觉提醒：

> 请将此密钥保存到安全的位置。源时不会提供服务器端密钥恢复能力。

---

# 9. 密钥规则

建议 V1 对“用户手动输入密钥”和“程序随机生成密钥”采用统一的 KDF 流程。

随机生成模式则：

```text
系统安全随机数
       ↓
256-bit Random Secret
       ↓
Base64URL 展示
       ↓
PBKDF2
       ↓
AES-256-GCM
```

用户输入模式：

```text
用户输入字符串
       ↓
UTF-8
       ↓
PBKDF2-HMAC-SHA256
       ↓
256-bit Derived Key
       ↓
AES-256-GCM
```

---

# 10. 本地加密方案

## 推荐

**AES-256-GCM**

理由：

- AES 为成熟国际标准。
- GCM 提供加密和完整性校验。
- 适合整体文件加密。
- 跨平台实现更加成熟。
- 后续如果 SourceTime 增加其他平台版本，数据格式更容易复用。

SM4 可以作为后续扩展，但 V1 不建议同时维护 AES 与 SM4 两套数据格式。

---

# 11. 密钥派生

建议：

```text
KDF = PBKDF2-HMAC-SHA256
Output = 32 Bytes
Salt = 16 Bytes Random
```

迭代次数不要在代码中散落写死，应定义为数据格式参数：

```ts
const KDF_ALGORITHM = "PBKDF2-HMAC-SHA256";
const KDF_KEY_LENGTH = 32;
const KDF_SALT_LENGTH = 16;
const KDF_ITERATIONS = 100000;
```

实际实现时，应以 HarmonyOS 当前 Crypto API 支持情况和安全建议为准；必要时调整迭代参数，并将参数写入加密文件头。

---

# 12. 本地数据格式

本地只保留一个加密数据文件：

```text
totp.db.enc
```

明文逻辑数据：

```json
{
  "version": 1,
  "items": [
    {
      "id": "uuid",
      "issuer": "GitHub",
      "account": "user@example.com",
      "secret": "JBSWY3DPEHPK3PXP",
      "algorithm": "SHA1",
      "digits": 6,
      "period": 30,
      "createdAt": 1727000000000,
      "updatedAt": 1727000000000
    }
  ]
}
```

上述 JSON 永远不能直接写入磁盘。

实际文件：

```text
┌───────────────────────────┐
│ Magic                     │
│ Format Version            │
│ KDF Algorithm             │
│ KDF Iterations            │
│ Salt                      │
│ IV / Nonce                │
│ Ciphertext                │
│ Authentication Tag        │
└───────────────────────────┘
```

---

# 13. WebDAV 配置

设置页面：

```text
WebDAV

服务器地址
┌───────────────────────────┐
│ https://example.com/dav/  │
└───────────────────────────┘

用户名
┌───────────────────────────┐
│ username                  │
└───────────────────────────┘

密码
┌───────────────────────────┐
│ ************              │
└───────────────────────────┘

同步目录
┌───────────────────────────┐
│ /SourceTime/              │
└───────────────────────────┘

[测试连接]

自动同步                 开
启动时自动拉取           开

[立即推送]
[立即拉取]
```

---

# 14. WebDAV 同步文件

远程目录默认：

```text
/SourceTime/
    totp.db.enc
```

只同步：

```text
totp.db.enc
```

不上传：

```text
secret.json
settings.json
key.txt
```

WebDAV 服务端永远只看到密文。

---

# 15. WebDAV 密码存储

WebDAV 密码属于敏感配置。

不能明文存储在普通 Preferences 中。

建议：

- 优先使用 HarmonyOS 安全存储能力。
- 若确实需要与应用主数据一起存储，也必须经过安全加密。
- UI 中始终使用密码类型输入。

WebDAV 用户名则可以普通配置存储。

---

# 16. TOTP 数据模型

```ts
export interface TotpItem {
  id: string;
  issuer: string;
  account: string;
  secret: string;
  algorithm: "SHA1" | "SHA256" | "SHA512";
  digits: 6 | 8;
  period: number;
  createdAt: number;
  updatedAt: number;
}
```

---

# 17. TOTP 页面

首页名称：

**验证码**

页面整体保持极简。

顶部：

```text
源时                                  ⚙
```

中间：

```text
GitHub
user@example.com

123 456

        ◯ 18
```

底部：

```text
                    ＋
```

---

# 18. TOTP 卡片

每个 TOTP 卡片显示：

```text
┌─────────────────────────────────┐
│ GitHub                           │
│ user@example.com                │
│                                 │
│ 123 456                 ◯ 18    │
└─────────────────────────────────┘
```

验证码使用较大的等宽字体。

建议：

- 6 位验证码：`123 456`
- 8 位验证码：`1234 5678`

点击验证码：

```text
复制成功
```

直接写入系统剪贴板。

---

# 19. 倒计时

默认周期：

```text
30 秒
```

每秒刷新。

计算：

```text
remaining = period - (unixTime % period)
```

剩余时间同时用于生成新的 TOTP。

不要单独维护一个“虚假的倒计时”。

---

# 20. TOTP 算法

严格按照 RFC 6238 实现。

支持：

- SHA1
- SHA256
- SHA512

支持：

- 6 位
- 8 位

支持：

- 默认 period = 30
- 允许解析 URI 中的自定义 period

---

# 21. 新增 TOTP

点击首页 `+`。

进入：

```text
添加验证码

[扫描二维码]

[手动输入]
```

---

# 22. 扫码录入

支持：

```text
otpauth://totp/...
```

示例：

```text
otpauth://totp/GitHub:user@example.com?secret=ABCDEF123456&issuer=GitHub&algorithm=SHA1&digits=6&period=30
```

解析：

| 字段 | 来源 |
|---|---|
| issuer | issuer 参数或 URI Label |
| account | URI Label |
| secret | secret |
| algorithm | algorithm |
| digits | digits |
| period | period |

扫描完成后不要直接保存。

先进入：

```text
确认验证码信息
```

让用户确认后再保存。

---

# 23. 手动录入

字段：

```text
发行方
GitHub

账号
user@example.com

密钥
ABCDEF123456

算法
SHA1

位数
6

周期
30

[保存]
```

其中：

- issuer 必填。
- account 建议必填。
- secret 必填。
- algorithm 默认 SHA1。
- digits 默认 6。
- period 默认 30。

保存前验证：

- Secret 是否为合法 Base32。
- digits 是否为支持值。
- period 是否有效。

---

# 24. 新增后的自动同步

如果 WebDAV 已配置并开启自动同步：

```text
保存 TOTP
   ↓
写入本地加密数据库
   ↓
刷新首页
   ↓
异步触发 Push
```

关键要求：

**本地保存成功后才能触发网络同步。**

不能出现：

```text
WebDAV 失败
↓
新增 TOTP 失败
```

正确行为应该是：

```text
本地成功
网络失败
↓
TOTP 仍然保留
↓
提示“同步失败”
```

---

# 25. 删除 TOTP

建议支持：

- 长按卡片。
- 左滑删除。
- 卡片菜单删除。

删除确认：

```text
删除验证码？

删除后该验证码将从本地数据中移除。

[取消] [删除]
```

删除完成：

```text
更新本地加密数据库
      ↓
自动 Push
```

---

# 26. 手动 Push

设置页面：

```text
立即推送
```

执行：

```text
加载本地数据
      ↓
重新加密/生成最新加密文件
      ↓
WebDAV PUT
      ↓
保存同步时间
```

成功：

```text
同步成功
```

失败：

```text
同步失败
原因：无法连接 WebDAV 服务器
```

---

# 27. 手动 Pull

执行：

```text
WebDAV GET
      ↓
取得 totp.db.enc
      ↓
使用用户密钥解密
      ↓
验证 Authentication Tag
      ↓
解析数据库
      ↓
覆盖本地数据库
      ↓
刷新首页
```

重点：

**必须先成功解密并验证数据完整性，再覆盖本地数据。**

禁止：

```text
下载
↓
直接覆盖
↓
再尝试解密
```

否则损坏文件可能导致本地数据丢失。

---

# 28. 自动同步策略

WebDAV 配置完成后：

| 事件 | 行为 |
|---|---|
| 新增 TOTP | 自动 Push |
| 删除 TOTP | 自动 Push |
| 启动 App | 自动 Pull（可关闭） |
| 手动 Push | Push |
| 手动 Pull | Pull |

自动同步失败不能阻塞页面操作。

---

# 29. 同步并发控制

必须避免：

```text
新增 A
新增 B
新增 C

同时触发三个 PUT
```

导致远程数据竞争。

建议 SyncService 增加同步队列：

```text
Sync Queue

Push
 ↓
Push
 ↓
Push
```

短时间内连续修改时，可以合并成一次最终 Push：

```text
新增 A
新增 B
删除 C
        ↓
合并
        ↓
只 Push 最终数据
```

---

# 30. 同步冲突策略

V1 不做复杂 Merge。

采用：

**Last Write Wins**

但实现时应该在加密文件头或明文元数据中保存：

```ts
revision: number
updatedAt: number
deviceId: string
```

推荐：

```text
revision + updatedAt
```

作为未来冲突解决的基础。

---

# 31. 推荐同步文件结构

建议不要只保存纯业务 JSON，而采用：

```json
{
  "version": 1,
  "revision": 12,
  "updatedAt": 1727000000000,
  "items": [...]
}
```

整个对象再进行 AES-256-GCM 加密。

这样 V2 可以扩展：

- 冲突检测
- 增量同步
- 设备识别
- 多端合并

---

# 32. 项目目录

建议：

```text
entry/src/main/ets/

├── pages/
│   ├── HomePage.ets
│   ├── AddTotpPage.ets
│   ├── ScanPage.ets
│   ├── SettingsPage.ets
│   ├── SecurityPage.ets
│   ├── WebDavPage.ets
│   ├── PrivacyPolicyPage.ets
│   └── AboutPage.ets
│
├── components/
│   ├── TotpCard.ets
│   ├── CountDown.ets
│   ├── SecretInput.ets
│   ├── PrivacyDialog.ets
│   └── EmptyState.ets
│
├── model/
│   ├── TotpItem.ts
│   ├── DatabaseModel.ts
│   ├── WebDavConfig.ts
│   └── Settings.ts
│
├── service/
│   ├── TotpService.ts
│   ├── OtpParser.ts
│   ├── CryptoService.ts
│   ├── StorageService.ts
│   ├── SyncService.ts
│   ├── WebDavService.ts
│   └── ClipboardService.ts
│
├── viewmodel/
│   ├── HomeViewModel.ts
│   ├── AddTotpViewModel.ts
│   ├── SecurityViewModel.ts
│   └── SettingsViewModel.ts
│
└── utils/
    ├── Base32.ts
    ├── Time.ts
    ├── UUID.ts
    └── Logger.ts
```

---

# 33. Service 职责

## TotpService

职责：

- TOTP 生成。
- 时间计算。
- SHA1/SHA256/SHA512。
- 6/8 位处理。

不能负责：

- UI。
- WebDAV。
- 本地文件读写。

---

## CryptoService

职责：

```ts
generateRandomKey()
deriveKey()
encrypt()
decrypt()
generateSalt()
generateNonce()
```

不得：

- 保存 Secret 到日志。
- 将 Derived Key 写入磁盘。
- 将用户密钥写入普通 Preferences。

---

## StorageService

职责：

```ts
loadDatabase()
saveDatabase()
addTotp()
deleteTotp()
replaceDatabase()
changeEncryptionKey()
```

所有持久化数据经过 CryptoService。

---

## WebDavService

只处理 WebDAV：

```ts
testConnection()
upload()
download()
```

不处理：

- TOTP
- 密钥
- UI

---

## SyncService

负责业务级同步编排：

```ts
push()
pull()
autoPush()
autoPull()
enqueuePush()
```

---

# 34. 隐私政策状态

增加：

```ts
privacyPolicyAccepted: boolean
privacyPolicyVersion: string
```

首次启动：

```text
privacyPolicyAccepted !== true
```

则显示隐私政策。

用户点击同意后：

```text
privacyPolicyAccepted = true
privacyPolicyVersion = CURRENT_PRIVACY_VERSION
```

后续如果隐私政策重大升级：

```text
CURRENT_PRIVACY_VERSION != savedVersion
```

再次要求用户确认。

---

# 35. 应用启动状态机

建议：

```text
APP_START
   ↓
检查隐私政策
   ↓
未同意 ─────→ PrivacyPolicy
   ↓
已同意
   ↓
检查加密密钥
   ↓
未初始化 ───→ SecuritySetup
   ↓
已初始化
   ↓
加载本地数据库
   ↓
Home
   ↓
WebDAV 已配置？
   ↓
是
   ↓
Auto Pull Enabled？
   ↓
是 → Pull
```

---

# 36. 密钥遗失处理

必须在用户第一次设置密钥时明确提示：

> 源时不会保存你的明文加密密钥，也不会提供服务器端找回功能。  
> 如果忘记或丢失密钥，之前加密的数据可能无法恢复。

修改密钥时：

```text
输入当前密钥
      ↓
解密成功
      ↓
输入新密钥
      ↓
重新加密
      ↓
保存
      ↓
如果配置 WebDAV
      ↓
自动 Push
```

如果旧密钥错误：

```text
修改失败
当前密钥不正确
```

---

# 37. 密钥复制安全设计

生成密钥后的复制功能：

```text
[复制]
```

点击后：

```text
密钥已复制
```

同时建议：

- 不记录复制内容日志。
- 不把密钥显示在 Toast 中。
- 如果 HarmonyOS 能力允许，可以在一定时间后清理剪贴板。
- 系统剪贴板是否能自动清理，以实际 API 能力为准。

---

# 38. 安全要求

以下要求为强制项。

### 禁止

```text
console.info(secret)
console.error(secret)
```

禁止。

### 禁止

```text
Preferences.set("secret", secret)
```

禁止。

### 禁止

将明文 JSON 上传 WebDAV。

### 禁止

内置默认加密密钥。

### 禁止

ECB。

### 禁止

无认证的 CBC。

### 禁止

自行设计密码学算法。

### 必须

使用系统安全随机数。

### 必须

AES-GCM。

### 必须

随机 Salt。

### 必须

随机 Nonce/IV。

### 必须

验证 Authentication Tag。

---

# 39. 错误处理

统一错误模型：

```ts
enum AppErrorCode {
  INVALID_TOTP_URI,
  INVALID_SECRET,
  INVALID_KEY,
  DECRYPT_FAILED,
  ENCRYPT_FAILED,
  WEBDAV_AUTH_FAILED,
  WEBDAV_CONNECTION_FAILED,
  WEBDAV_UPLOAD_FAILED,
  WEBDAV_DOWNLOAD_FAILED,
  INVALID_REMOTE_DATA
}
```

错误展示给用户的是可理解的中文。

例如：

```text
无法解密数据
请确认使用的是正确的加密密钥。
```

而不是：

```text
AES_GCM_AUTH_TAG_MISMATCH
```

底层技术错误可以写开发日志，但不得写入 Secret、密钥或密码。

---

# 40. UI 页面列表

最终 V1 页面：

```text
隐私政策
    ↓
加密密钥初始化
    ↓
首页
 ├── 添加验证码
 │    ├── 扫码
 │    └── 手动输入
 │
 └── 设置
      ├── 安全
      ├── WebDAV
      ├── 同步
      ├── 隐私政策
      └── 关于
```

---

# 41. 首页 UI 原则

源时首页应该非常简单。

只突出：

```text
账号
验证码
倒计时
```

不需要复杂的 Dashboard。

推荐：

- 卡片式布局。
- 大字号验证码。
- 清晰倒计时。
- 点击即复制。
- 长按删除。
- 顶部设置。
- 底部添加。

---

# 42. 开发阶段拆分

## Phase 0：工程初始化

完成：

- HarmonyOS NEXT 工程。
- ArkTS。
- 页面路由。
- 基础主题。
- 深色模式。

---

## Phase 1：隐私政策

完成：

- 首次启动检测。
- 隐私政策弹窗。
- 隐私政策页面。
- 同意状态持久化。
- 隐私政策版本管理。

---

## Phase 2：安全模块

完成：

- 密钥输入。
- 随机密钥生成。
- 密钥复制。
- PBKDF2。
- AES-256-GCM。
- 本地加密数据库。

---

## Phase 3：TOTP

完成：

- TOTP RFC 6238。
- SHA1。
- SHA256。
- SHA512。
- 6/8 位。
- 自定义 period。
- 倒计时。
- Clipboard。

---

## Phase 4：二维码

完成：

- Scan Kit。
- otpauth URI。
- Base32。
- 参数解析。
- 扫码确认页。

---

## Phase 5：WebDAV

完成：

- URL。
- 用户名。
- 密码。
- 目录。
- PROPFIND。
- GET。
- PUT。
- 测试连接。

---

## Phase 6：同步

完成：

- 手动 Push。
- 手动 Pull。
- 新增自动 Push。
- 删除自动 Push。
- 启动 Auto Pull。
- 同步队列。
- 同步状态。

---

## Phase 7：安全与测试

必须完成：

- 单元测试。
- TOTP RFC 测试向量。
- 加密/解密测试。
- 错误密钥测试。
- 损坏密文测试。
- WebDAV 失败测试。
- 断网测试。
- 重复快速新增/删除测试。
- App 重启测试。

---

# 43. AI Coding 工作规则

以后让 AI 根据本项目实现代码时，必须遵守：

## 架构

采用：

```text
Page
 ↓
ViewModel
 ↓
Service
 ↓
Storage / Crypto / WebDAV
```

页面不直接访问：

- 文件
- Crypto API
- WebDAV
- TOTP 核心算法

---

## 安全

任何新代码必须优先考虑：

```text
Secret 是否进入日志？
Secret 是否进入普通存储？
Key 是否写盘？
是否上传了明文？
```

发现任何一种情况都必须修改。

---

## 同步

本地数据永远是第一优先级。

```text
Local Success
≠
Sync Success
```

网络同步失败不能回滚本地用户操作。

---

## UI

优先 HarmonyOS 原生组件与设计语言。

避免为了简单而把大量业务代码塞在 `.ets` Page 文件中。

---

# 44. V1 最终技术决策

| 项目 | 决策 |
|---|---|
| 项目名称 | **源时（SourceTime）** |
| 平台 | HarmonyOS NEXT |
| 开发语言 | ArkTS |
| TOTP | RFC 6238 |
| Hash | SHA1 / SHA256 / SHA512 |
| OTP 位数 | 6 / 8 |
| 默认周期 | 30 秒 |
| 加密 | **AES-256-GCM** |
| KDF | PBKDF2-HMAC-SHA256 |
| 随机密钥 | 256-bit |
| 本地格式 | 加密 JSON 单文件 |
| WebDAV | GET / PUT / PROPFIND |
| 远程文件 | `totp.db.enc` |
| 同步模式 | Offline First |
| 新增自动同步 | Push |
| 删除自动同步 | Push |
| 启动同步 | Auto Pull，可关闭 |
| 冲突策略 | V1 Last Write Wins |
| 隐私政策 | 首次启动必须确认 |
| 加密密钥 | 用户输入或随机生成 |
| 密钥复制 | 支持 |
| 开源协议 | MIT / Apache-2.0 二选一 |

---

# 45. AI 实现时的第一条系统级要求

后续生成代码时，请始终将以下规则作为 SourceTime 的最高优先级：

> **SourceTime 的 TOTP Secret、用户加密密钥和 WebDAV 密码均属于敏感数据。任何实现都不得以明文形式持久化、上传、记录日志或通过异常信息泄露。**

其次：

> **任何本地数据变更必须先确保本地加密存储成功，再执行 WebDAV 同步。WebDAV 同步失败不得导致本地数据丢失。**

最后：

> **隐私政策确认和加密密钥初始化是首次使用流程的一部分，不得绕过。**
