# SourceTime AI Coding 实施规范

**项目名称：源时（SourceTime）**  
**项目类型：HarmonyOS 开源 TOTP Authenticator**  
**文档定位：AI Coding 工程实施规范**  
**配套需求文档：`SourceTime_HarmonyOS_TOTP_Implementation_Plan_v1.1.md`**

---

# 1. 文档目的

本文档用于指导 AI Coding 工具、AI Agent 或开发人员实现 SourceTime。

与产品规划文档不同，本文件重点规定：

- 工程结构
- 模块职责
- 接口契约
- 数据模型
- 状态管理
- 加密数据格式
- TOTP 实现边界
- WebDAV 实现边界
- 页面与 Service 的调用关系
- 错误处理
- 测试策略
- 开发顺序
- 每个阶段的完成标准

AI 在实现 SourceTime 时，应将本文档作为**工程实现约束**，将产品规划文档作为**功能需求约束**。

若两个文档出现冲突：

1. 安全约束优先。
2. 数据完整性优先。
3. 本实施规范优先于示例代码。
4. 实际 HarmonyOS SDK API 约束优先于本文中的假设 API 名称。
5. 不得为了通过编译而绕过安全检查。

---

# 2. 核心工程原则

## 2.1 本地优先

所有用户数据变更遵循：

```text
用户操作
   ↓
业务校验
   ↓
修改内存状态
   ↓
本地加密持久化成功
   ↓
更新 UI
   ↓
异步触发同步
```

禁止：

```text
用户操作
   ↓
先上传 WebDAV
   ↓
WebDAV 成功后再保存本地
```

---

## 2.2 网络不是核心依赖

以下功能在完全断网情况下必须正常：

- 查看 TOTP
- 添加 TOTP
- 删除 TOTP
- 生成验证码
- 复制验证码
- 设置/修改加密密钥
- 查看本地设置

只有以下功能依赖网络：

- WebDAV 测试
- Push
- Pull
- 自动同步

---

## 2.3 安全数据最小暴露

敏感数据包括：

- TOTP Secret
- 用户加密密钥
- PBKDF2 Derived Key
- WebDAV Password
- 明文 TOTP Database

敏感数据只能在必要的 Service 内短时间存在。

禁止：

- `console.info(secret)`
- `console.info(key)`
- 将 Secret 放进页面 State 后长期保存
- 将 Derived Key 保存到磁盘
- 将明文 TOTP JSON 上传 WebDAV
- 在错误消息中返回 Secret
- 将 WebDAV 密码写入普通日志

---

## 2.4 UI 不实现业务逻辑

页面层只负责：

- UI
- 用户输入
- 页面状态
- 用户操作事件
- 调用 ViewModel

禁止页面直接：

- 调用文件 API
- 调用 Crypto API
- 发送 WebDAV 请求
- 计算 TOTP
- 解析 `otpauth://`
- 修改数据库文件

---

# 3. 推荐架构

采用：

```text
┌────────────────────────────┐
│            Page            │
│ UI / User Interaction      │
└─────────────┬──────────────┘
              │
              ▼
┌────────────────────────────┐
│          ViewModel         │
│ 页面状态 / UI Action       │
└─────────────┬──────────────┘
              │
              ▼
┌────────────────────────────────────────┐
│               Service                  │
│ TOTP / Storage / Crypto / Sync / DAV │
└─────────────┬──────────────────────────┘
              │
              ▼
┌────────────────────────────────────────┐
│ HarmonyOS Platform APIs                │
│ File / Crypto / Network / Scan / Clip │
└────────────────────────────────────────┘
```

---

# 4. 工程目录规范

建议：

```text
entry/
└── src/
    └── main/
        ├── ets/
        │   ├── pages/
        │   │   ├── HomePage.ets
        │   │   ├── AddTotpPage.ets
        │   │   ├── ScanPage.ets
        │   │   ├── SecurityPage.ets
        │   │   ├── WebDavPage.ets
        │   │   ├── PrivacyPolicyPage.ets
        │   │   └── AboutPage.ets
        │   │
        │   ├── components/
        │   │   ├── TotpCard.ets
        │   │   ├── EmptyState.ets
        │   │   ├── CountDown.ets
        │   │   ├── SecretInput.ets
        │   │   └── PrivacyDialog.ets
        │   │
        │   ├── viewmodel/
        │   │   ├── HomeViewModel.ets
        │   │   ├── AddTotpViewModel.ets
        │   │   ├── SecurityViewModel.ets
        │   │   ├── WebDavViewModel.ets
        │   │   └── SettingsViewModel.ets
        │   │
        │   ├── service/
        │   │   ├── TotpService.ets
        │   │   ├── OtpParser.ets
        │   │   ├── CryptoService.ets
        │   │   ├── StorageService.ets
        │   │   ├── WebDavService.ets
        │   │   ├── SyncService.ets
        │   │   └── ClipboardService.ets
        │   │
        │   ├── model/
        │   │   ├── TotpItem.ets
        │   │   ├── DatabaseModel.ets
        │   │   ├── WebDavConfig.ets
        │   │   ├── SettingsModel.ets
        │   │   └── SyncModel.ets
        │   │
        │   ├── repository/
        │   │   ├── LocalRepository.ets
        │   │   └── SyncRepository.ets
        │   │
        │   ├── utils/
        │   │   ├── Base32Utils.ets
        │   │   ├── TimeUtils.ets
        │   │   ├── UUIDUtils.ets
        │   │   ├── UrlUtils.ets
        │   │   └── Logger.ets
        │   │
        │   ├── constants/
        │   │   ├── AppConstants.ets
        │   │   ├── CryptoConstants.ets
        │   │   └── SyncConstants.ets
        │   │
        │   └── types/
        │       ├── Result.ets
        │       └── Errors.ets
        │
        └── resources/
```

---

# 5. 模块依赖规则

允许：

```text
Page
 ↓
ViewModel
 ↓
Service
 ↓
Repository / Platform API
```

不允许：

```text
Page → WebDavService
Page → CryptoService
Page → File API
Page → HTTP API
```

不允许：

```text
TotpService → Page
CryptoService → Page
WebDavService → Page
```

Service 不得依赖 UI。

---

# 6. 核心数据模型

## 6.1 TotpItem

```ts
export interface TotpItem {
  id: string;
  issuer: string;
  account: string;
  secret: string;
  algorithm: TotpAlgorithm;
  digits: 6 | 8;
  period: number;
  createdAt: number;
  updatedAt: number;
}
```

---

## 6.2 TotpAlgorithm

```ts
export type TotpAlgorithm =
  | 'SHA1'
  | 'SHA256'
  | 'SHA512';
```

---

## 6.3 DatabaseModel

```ts
export interface DatabaseModel {
  version: number;
  revision: number;
  updatedAt: number;
  deviceId: string;
  items: TotpItem[];
}
```

注意：

`DatabaseModel` 在解密后的内存中存在。

持久化时必须：

```text
DatabaseModel
   ↓
JSON.stringify
   ↓
UTF-8 bytes
   ↓
AES-GCM Encrypt
   ↓
Binary File
```

---

# 7. WebDAV 配置模型

```ts
export interface WebDavConfig {
  enabled: boolean;
  baseUrl: string;
  username: string;
  password: string;
  remotePath: string;
  autoPush: boolean;
  autoPullOnStart: boolean;
}
```

密码不能直接进入普通 Preferences。

需要通过安全存储机制或加密方式保存。

---

# 8. Settings 模型

```ts
export interface SettingsModel {
  privacyPolicyAccepted: boolean;
  privacyPolicyVersion: string;

  encryptionInitialized: boolean;

  webDavEnabled: boolean;
  autoPush: boolean;
  autoPullOnStart: boolean;

  lastSyncAt?: number;
}
```

---

# 9. 同步状态模型

```ts
export enum SyncStatus {
  IDLE = 'IDLE',
  PUSHING = 'PUSHING',
  PULLING = 'PULLING',
  SUCCESS = 'SUCCESS',
  FAILED = 'FAILED'
}
```

```ts
export interface SyncState {
  status: SyncStatus;
  lastSyncAt?: number;
  message?: string;
}
```

---

# 10. Result 类型

Service 不建议通过异常字符串直接向 UI 传递业务状态。

定义统一结果：

```ts
export interface Result<T> {
  success: boolean;
  data?: T;
  error?: AppError;
}
```

---

# 11. AppError

```ts
export enum AppErrorCode {
  UNKNOWN,
  INVALID_INPUT,

  PRIVACY_NOT_ACCEPTED,

  INVALID_TOTP_URI,
  INVALID_TOTP_SECRET,
  INVALID_TOTP_CONFIG,

  KEY_REQUIRED,
  INVALID_KEY,
  ENCRYPT_FAILED,
  DECRYPT_FAILED,
  INVALID_ENCRYPTED_FILE,

  STORAGE_READ_FAILED,
  STORAGE_WRITE_FAILED,

  WEBDAV_INVALID_URL,
  WEBDAV_AUTH_FAILED,
  WEBDAV_CONNECTION_FAILED,
  WEBDAV_UPLOAD_FAILED,
  WEBDAV_DOWNLOAD_FAILED,
  WEBDAV_INVALID_REMOTE_FILE,

  SYNC_CONFLICT,
  SYNC_BUSY
}
```

```ts
export interface AppError {
  code: AppErrorCode;
  message: string;
}
```

用户界面显示中文可读消息。

底层异常对象不要直接展示给用户。

---

# 12. Service：TotpService

## 职责

只负责 TOTP：

- 生成验证码
- 计算时间窗口
- Base32 Secret 转 bytes
- HMAC
- 动态截断
- 格式化验证码

不负责：

- 存储
- UI
- WebDAV
- 日志

---

## 12.1 接口

```ts
export interface GenerateTotpOptions {
  secret: string;
  algorithm: TotpAlgorithm;
  digits: 6 | 8;
  period: number;
  timestamp?: number;
}
```

```ts
generate(options: GenerateTotpOptions): Result<string>;
```

---

# 13. TOTP 计算要求

标准流程：

```text
Unix Timestamp
      ↓
floor(timestamp / period)
      ↓
8-byte big-endian counter
      ↓
HMAC-SHA1/SHA256/SHA512
      ↓
Dynamic Truncation
      ↓
mod 10^digits
      ↓
zero-pad
```

不得自定义 TOTP 算法。

---

# 14. 倒计时计算

统一函数：

```ts
calculateRemainingSeconds(
  timestamp: number,
  period: number
): number;
```

建议：

```text
remaining = period - (floor(timestamp / 1000) % period)
```

页面 Timer 不应自行复制公式。

---

# 15. Service：OtpParser

## 职责

解析：

```text
otpauth://totp/...
```

支持：

- issuer
- account
- secret
- algorithm
- digits
- period

---

## 15.1 Parser 输出

```ts
export interface ParsedOtpUri {
  issuer: string;
  account: string;
  secret: string;
  algorithm: TotpAlgorithm;
  digits: 6 | 8;
  period: number;
}
```

---

# 16. OTP URI 解析规则

典型：

```text
otpauth://totp/{label}?secret=...&issuer=...
```

Label：

```text
Issuer:Account
```

优先使用标准 URI 参数：

```text
issuer
```

如果参数不存在，再考虑从 label 提取 issuer。

Secret：

- 必须存在。
- 必须通过 Base32 校验。

Algorithm：

默认：

```text
SHA1
```

Digits：

默认：

```text
6
```

Period：

默认：

```text
30
```

---

# 17. Service：CryptoService

这是整个项目最重要的 Service 之一。

## 职责

- 生成随机 Secret
- KDF
- AES-GCM 加密
- AES-GCM 解密
- Salt / Nonce 生成
- 加密文件序列化
- 加密文件反序列化

---

# 18. CryptoService 接口

```ts
export interface CryptoService {
  generateRandomEncryptionSecret(): Promise<string>;

  deriveKey(
    userSecret: string,
    salt: Uint8Array,
    iterations: number
  ): Promise<Uint8Array>;

  encrypt(
    plaintext: Uint8Array,
    userSecret: string
  ): Promise<Uint8Array>;

  decrypt(
    encryptedData: Uint8Array,
    userSecret: string
  ): Promise<Uint8Array>;
}
```

实际项目可以根据 HarmonyOS Crypto API 类型进行调整。

---

# 19. 加密参数

推荐：

```ts
const CRYPTO_FORMAT_VERSION = 1;

const KDF_ALGORITHM = 'PBKDF2-HMAC-SHA256';

const KDF_KEY_LENGTH = 32;

const SALT_LENGTH = 16;

const NONCE_LENGTH = 12;

const GCM_TAG_LENGTH = 16;
```

迭代次数定义为可升级参数：

```ts
const KDF_ITERATIONS = 100000;
```

实际落地时必须基于目标 HarmonyOS SDK 所提供的密码 API 进行验证。

---

# 20. 随机密钥生成

随机密钥：

```text
32 bytes
```

使用：

```text
密码学安全随机数
```

编码：

```text
Base64URL
```

避免使用：

```text
Math.random()
```

---

# 21. 为什么生成的 256-bit Secret 还要经过 KDF

为了统一“用户输入密钥”和“随机生成密钥”的处理流程。

统一：

```text
User Secret
     ↓
PBKDF2
     ↓
AES Key
```

这样加密文件格式可以统一。

如果后续产品决定对“机器生成的高熵密钥”采用直接 AES key，也需要新增明确的数据格式版本，不允许在代码中隐式判断。

---

# 22. 加密文件格式

推荐二进制格式：

```text
MAGIC
VERSION
KDF_ALGORITHM_ID
KDF_ITERATIONS
SALT
NONCE
CIPHERTEXT
TAG
```

示意：

```text
┌───────────────┐
│ MAGIC         │
├───────────────┤
│ VERSION       │
├───────────────┤
│ KDF PARAMS    │
├───────────────┤
│ SALT          │
├───────────────┤
│ NONCE         │
├───────────────┤
│ CIPHERTEXT    │
├───────────────┤
│ AUTH TAG      │
└───────────────┘
```

所有参数必须能够让未来版本识别和迁移。

---

# 23. 不允许把密钥保存为“配置文件”

禁止：

```text
key.txt
master.key
secret.key
```

禁止将用户输入密钥或 Derived Key 写入应用文件目录。

应用只能保存：

- 是否已完成初始化
- 加密数据
- KDF 参数
- WebDAV 配置
- 非敏感业务设置

---

# 24. Service：StorageService

## 职责

- 加载数据库
- 保存数据库
- 添加 TOTP
- 删除 TOTP
- 修改密钥
- 获取当前内存数据
- 原子写入

---

# 25. StorageService 接口

```ts
interface StorageService {
  initialize(): Promise<Result<void>>;

  loadDatabase(
    encryptionSecret: string
  ): Promise<Result<DatabaseModel>>;

  saveDatabase(
    database: DatabaseModel,
    encryptionSecret: string
  ): Promise<Result<void>>;

  replaceDatabase(
    database: DatabaseModel,
    encryptionSecret: string
  ): Promise<Result<void>>;

  changeEncryptionSecret(
    oldSecret: string,
    newSecret: string
  ): Promise<Result<void>>;
}
```

---

# 26. 原子写入要求

保存数据库不能直接：

```text
write(totp.db.enc)
```

建议：

```text
生成新加密文件
      ↓
写入临时文件
      ↓
fsync / flush（以平台 API 能力为准）
      ↓
校验写入成功
      ↓
替换正式文件
```

例如：

```text
totp.db.enc.tmp
        ↓
成功
        ↓
totp.db.enc
```

目的是避免应用崩溃导致主数据文件损坏。

---

# 27. Service：WebDavService

## 职责

仅负责 HTTP/WebDAV 协议操作。

接口：

```ts
interface WebDavService {
  testConnection(config: WebDavConfig): Promise<Result<void>>;

  upload(
    config: WebDavConfig,
    data: Uint8Array
  ): Promise<Result<void>>;

  download(
    config: WebDavConfig
  ): Promise<Result<Uint8Array>>;
}
```

---

# 28. WebDAV HTTP 方法

V1 支持：

```text
PROPFIND
GET
PUT
```

可选：

```text
MKCOL
```

用于自动创建目录。

不需要：

```text
DELETE
MOVE
COPY
LOCK
UNLOCK
```

除非后续需求明确增加。

---

# 29. WebDAV URL 处理

配置：

```text
https://example.com/dav/
```

远程目录：

```text
/SourceTime/
```

文件：

```text
/SourceTime/totp.db.enc
```

代码中必须正确处理：

- `/`
- URL encode
- 空目录
- Unicode 路径
- 已经包含路径的 Base URL

不得简单字符串拼接导致：

```text
https://example.com/dav//SourceTime/
```

---

# 30. WebDAV 认证

V1 可支持：

```text
HTTP Basic Authentication
```

要求：

- 使用 HTTPS。
- 不在日志中打印 Authorization Header。
- 不打印密码。
- 不显示完整请求 Header。

HTTP 明文 URL：

```text
http://
```

建议默认提示用户存在安全风险。

---

# 31. Service：SyncService

SyncService 是同步业务编排层。

它不能直接修改 UI。

---

## 31.1 核心接口

```ts
interface SyncService {
  push(): Promise<Result<void>>;

  pull(): Promise<Result<void>>;

  enqueuePush(reason: SyncReason): Promise<Result<void>>;

  autoPullOnStart(): Promise<Result<void>>;

  getState(): SyncState;
}
```

---

# 32. SyncReason

```ts
export enum SyncReason {
  MANUAL,
  ADD_TOTP,
  DELETE_TOTP,
  CHANGE_SETTINGS,
  STARTUP
}
```

---

# 33. Push 流程

严格执行：

```text
读取当前本地数据库
       ↓
更新 revision / updatedAt
       ↓
序列化 JSON
       ↓
AES-GCM 加密
       ↓
生成 totp.db.enc
       ↓
WebDAV PUT
       ↓
成功
       ↓
更新 lastSyncAt
```

如果失败：

```text
本地数据不回滚
```

---

# 34. Pull 流程

严格执行：

```text
WebDAV GET
      ↓
得到 bytes
      ↓
解析加密文件头
      ↓
检查版本
      ↓
AES-GCM decrypt
      ↓
验证 Authentication Tag
      ↓
JSON Parse
      ↓
Schema Validate
      ↓
Revision / updatedAt 检查
      ↓
写入临时本地数据库
      ↓
原子替换
      ↓
通知 UI 刷新
```

禁止先覆盖本地文件再解密。

---

# 35. Pull 安全规则

远程文件必须全部验证：

- Magic
- Version
- KDF 参数
- Salt 长度
- Nonce 长度
- Ciphertext 长度
- Authentication Tag
- JSON 格式
- Schema
- `version`
- `items`
- TOTP 字段

任意一步失败：

```text
Pull 失败
本地数据保持不变
```

---

# 36. 同步队列

禁止同一时间发送多个 Push。

错误示例：

```text
Push A
Push B
Push C
```

正确：

```text
Push requested
      ↓
已有 Push 正在执行？
      ↓
是
      ↓
标记 dirty
      ↓
当前 Push 完成
      ↓
dirty ?
      ↓
再 Push 一次最终状态
```

这比简单的 Promise 叠加更稳定。

---

# 37. Auto Push

新增：

```text
Storage Save
   ↓
Save Success
   ↓
autoPush enabled?
   ↓
yes
   ↓
enqueuePush(ADD_TOTP)
```

删除：

```text
Storage Save
   ↓
Save Success
   ↓
autoPush enabled?
   ↓
yes
   ↓
enqueuePush(DELETE_TOTP)
```

---

# 38. Auto Pull

App 启动：

```text
Privacy Accepted
        ↓
Encryption Initialized
        ↓
Local Database Loaded
        ↓
Home
        ↓
WebDAV Configured?
        ↓
Auto Pull Enabled?
        ↓
后台执行 Pull
```

Auto Pull 不能阻塞首页显示。

---

# 39. Pull 与本地脏数据

必须考虑：

```text
本地刚刚新增一个 TOTP
        ↓
此时启动 Pull
        ↓
远程数据比较旧
```

V1 至少要进行 Revision / UpdatedAt 检查。

不得无条件覆盖本地最新数据。

建议：

```text
remoteRevision < localRevision
```

时拒绝覆盖，并提示：

```text
远程数据不是最新版本
```

V2 再实现真正 Merge。

---

# 40. Revision 规则

每次本地成功写入数据：

```text
revision += 1
```

Pull 成功后：

```text
localRevision = remoteRevision
```

Revision 应当是数据库的一部分，而不是只存在 Settings。

---

# 41. Device ID

生成一个随机 Device ID：

```text
UUID
```

只用于同步元数据。

不要使用：

- IMEI
- Serial Number
- MAC Address
- OAID
- 精确设备标识

除非未来有明确需求。

---

# 42. ViewModel：HomeViewModel

状态：

```ts
interface HomeState {
  items: TotpItem[];
  loading: boolean;
  syncing: boolean;
  syncStatus: SyncStatus;
  lastSyncAt?: number;
  now: number;
}
```

职责：

- 加载 TOTP
- 删除 TOTP
- 复制验证码
- 刷新当前时间
- 响应同步状态

---

# 43. Home Timer

页面需要一个统一 Timer。

建议：

```text
每 1 秒更新 now
```

然后：

```text
TotpService.generate({
  ...item,
  timestamp: now
})
```

不要每个卡片创建一个独立 Timer。

错误：

```text
Card A -> Timer
Card B -> Timer
Card C -> Timer
...
```

正确：

```text
HomeViewModel -> one timer
                   ↓
                all cards
```

---

# 44. ViewModel：AddTotpViewModel

状态：

```ts
interface AddTotpState {
  mode: 'SCAN' | 'MANUAL';

  issuer: string;
  account: string;
  secret: string;

  algorithm: TotpAlgorithm;
  digits: 6 | 8;
  period: number;

  saving: boolean;
  error?: string;
}
```

职责：

- 解析扫码结果
- 验证手动输入
- 创建 TotpItem
- 调用 StorageService
- 成功后触发 SyncService

---

# 45. ViewModel：SecurityViewModel

状态：

```ts
interface SecurityState {
  encryptionInitialized: boolean;

  secret: string;

  loading: boolean;

  generated: boolean;

  error?: string;
}
```

操作：

```ts
generateSecret()
copySecret()
saveSecret()
changeSecret()
```

---

# 46. 首次启动状态机

必须有明确状态。

```ts
enum AppStartupState {
  CHECK_PRIVACY,
  SHOW_PRIVACY,
  CHECK_ENCRYPTION,
  SETUP_ENCRYPTION,
  LOAD_DATABASE,
  READY,
  ERROR
}
```

流程：

```text
APP START
   ↓
CHECK_PRIVACY
   ↓
SHOW_PRIVACY ──→ user accept
   ↓
CHECK_ENCRYPTION
   ↓
SETUP_ENCRYPTION ──→ save
   ↓
LOAD_DATABASE
   ↓
READY
```

---

# 47. Privacy Policy 实现要求

需要保存：

```ts
privacyPolicyAccepted: boolean
privacyPolicyVersion: string
```

当前版本定义：

```ts
const CURRENT_PRIVACY_POLICY_VERSION = '1.0';
```

不能只保存：

```text
accepted=true
```

因为未来需要版本升级。

---

# 48. PrivacyDialog 行为

未同意：

```text
[不同意]
[同意并继续]
```

“不同意”：

- 不进入主功能。
- 不初始化 TOTP 数据。
- 不自动配置同步。
- 不创建 WebDAV 请求。

“同意”：

- 保存同意状态。
- 进入加密初始化。

---

# 49. 页面路由要求

至少：

```text
/                         HomePage
/add                      AddTotpPage
/scan                     ScanPage
/settings/security        SecurityPage
/settings/webdav          WebDavPage
/settings/privacy         PrivacyPolicyPage
/settings/about           AboutPage
```

实际路由方式以 HarmonyOS 当前项目模板为准。

---

# 50. SecurityPage UI 规范

页面：

```text
保护你的数据

加密密钥

┌────────────────────────────┐
│ 输入密钥             [生成] │
└────────────────────────────┘

[复制]

提示：
请妥善保存加密密钥。
忘记密钥后无法恢复已加密数据。

[保存]
```

如果已生成：

- 自动填充。
- 显示复制图标。
- 提供重新生成操作时必须二次确认。

---

# 51. 重新生成密钥的危险操作

不能点击后直接覆盖当前密钥。

正确：

```text
点击生成
      ↓
确认“重新生成”
      ↓
生成新密钥
      ↓
需要用户显式保存
      ↓
保存时重新加密数据库
```

如果当前已有数据：

```text
生成新密钥 ≠ 立即替换数据库密钥
```

必须在“确认保存新密钥”后才真正换钥。

---

# 52. 修改密钥流程

```text
输入旧密钥
      ↓
尝试解密当前数据库
      ↓
失败
      ↓
提示旧密钥错误

成功
      ↓
输入新密钥
      ↓
重新加密
      ↓
原子替换
      ↓
WebDAV 自动 Push（若开启）
```

---

# 53. WebDavPage UI

包括：

- Enable 开关
- Server URL
- Username
- Password
- Remote directory
- Test Connection
- Auto Push
- Auto Pull on Start
- Manual Push
- Manual Pull
- Last Sync Time
- Current Sync State

---

# 54. WebDAV 测试连接

“测试连接”不应该修改本地数据。

流程：

```text
读取配置
   ↓
验证 URL
   ↓
PROPFIND
   ↓
检查 HTTP Status
   ↓
成功
```

成功仅代表：

```text
服务器可连接
认证可用
目录可访问
```

不能表示：

```text
同步一定成功
```

---

# 55. HTTP Status 处理

建议：

```text
2xx → Success
401 → Authentication Failed
403 → Permission Denied
404 → Remote Path Not Found
408 → Timeout
429 → Too Many Requests
5xx → Server Error
```

UI 给用户可读错误。

---

# 56. ClipboardService

接口：

```ts
interface ClipboardService {
  copyText(text: string): Promise<Result<void>>;
}
```

用于：

- TOTP 验证码
- 生成的加密密钥

不要让页面直接调用系统 Clipboard API。

---

# 57. Logger 规范

Logger 可以存在：

```ts
Logger.debug()
Logger.info()
Logger.warn()
Logger.error()
```

但必须提供敏感信息过滤。

禁止：

```ts
Logger.debug(`secret=${secret}`)
```

禁止：

```ts
Logger.error(JSON.stringify(database))
```

禁止：

```ts
Logger.error(JSON.stringify(webDavConfig))
```

尤其禁止打印 password。

---

# 58. 建议的日志内容

可以记录：

```text
TOTP added: id=xxx
TOTP deleted: id=xxx
Sync started
Sync finished
WebDAV request failed: status=401
Database loaded
Database save success
```

其中：

`id` 可以记录。

`secret` 不可以记录。

---

# 59. Schema Validation

远程数据库解密成功之后不能立即使用。

必须：

```text
decrypt
  ↓
parse JSON
  ↓
validate schema
  ↓
validate TOTP items
  ↓
accept
```

对每条 TotpItem 检查：

- `id` 为非空字符串
- `issuer` 为字符串
- `account` 为字符串
- `secret` 合法 Base32
- `algorithm` 为合法值
- `digits` 为 6/8
- `period` > 0
- 时间戳合理

---

# 60. Add TOTP 输入校验

保存前：

```text
issuer.trim() !== ''
account.trim() !== ''
secret.trim() !== ''
```

Secret：

- 删除空白字符
- 转大写
- Base32 标准字符检查

可选择兼容：

```text
0 → O
1 → I/L
```

但必须是明确产品策略，不能静默进行可能改变 Secret 的转换。

V1 建议严格校验，发现错误直接提示用户。

---

# 61. TOTP Secret 内存处理

ArkTS/JavaScript 环境无法像原生 C/C++ 一样保证字符串立即清零。

因此：

- 尽量缩短 Secret 生命周期。
- 不建立不必要的全局缓存。
- 不复制 Secret。
- 不放入长期页面 State，除非当前编辑页面必须使用。
- 离开页面后清理相关引用。
- 不写入日志。

---

# 62. 数据库内存策略

推荐：

```text
StorageService
     ↓
loadDatabase()
     ↓
Application-level memory cache
```

避免每展示一个验证码都重新读取磁盘。

但是：

- 修改数据必须先写磁盘。
- 内存不是唯一数据源。
- App 重启必须能够从加密文件恢复。

---

# 63. Repository 层

建议增加：

```text
LocalRepository
SyncRepository
```

职责：

### LocalRepository

封装：

- 文件
- StorageService
- CryptoService

### SyncRepository

封装：

- WebDavService
- SyncService

Page / ViewModel 不直接感知底层协议。

---

# 64. 加密文件迁移

文件格式必须带：

```text
version
```

未来：

```text
version 1
version 2
version 3
```

支持迁移：

```text
read v1
   ↓
parse
   ↓
migrate
   ↓
write v2
```

禁止直接修改旧格式解释规则，避免旧数据无法打开。

---

# 65. WebDAV 目录初始化

如果目录不存在：

```text
PROPFIND
     ↓
404
     ↓
MKCOL
     ↓
再次 PROPFIND
```

如果目标服务不支持 MKCOL：

- 给出明确提示。
- 不破坏本地数据。

---

# 66. 数据同步的最小粒度

V1：

```text
整个数据库文件同步
```

不实现：

```text
单条 TOTP PATCH
```

优点：

- 实现简单。
- 数据一致性高。
- WebDAV 兼容性好。
- 加密边界清晰。

---

# 67. 同步文件不包含 WebDAV 配置

远程 `totp.db.enc` 不应包含：

```text
WebDAV URL
WebDAV Username
WebDAV Password
```

避免配置泄漏以及跨设备复制不必要的信息。

同步数据库只包含：

```text
TOTP data
revision
updatedAt
deviceId
schema version
```

---

# 68. WebDAV 配置与 TOTP 密钥分离

WebDAV 配置属于设备本地配置。

加密密钥也是设备本地输入。

远程同步文件只承载：

```text
encrypted TOTP database
```

跨设备恢复流程要求：

```text
安装 SourceTime
      ↓
同意隐私政策
      ↓
输入原来的加密密钥
      ↓
配置相同 WebDAV
      ↓
Pull
      ↓
成功解密
```

不能通过 WebDAV 文件恢复加密密钥。

---

# 69. UI 反馈规范

长期任务：

```text
syncing
loading
saving
```

必须有明确状态。

短任务：

```text
copy
delete
save
```

可使用 Toast / Snackbar。

错误消息：

- 简短
- 说明问题
- 给出下一步

例如：

```text
无法解密数据
请检查加密密钥是否正确。
```

---

# 70. 删除 TOTP 的状态更新

顺序：

```text
用户确认删除
      ↓
从内存数据库删除
      ↓
更新 revision
      ↓
saveDatabase()
      ↓
成功
      ↓
刷新 UI
      ↓
enqueuePush()
```

如果 save 失败：

```text
UI 保持原状态
```

不能在本地持久化失败时假装删除成功。

---

# 71. 新增 TOTP 的状态更新

顺序：

```text
表单校验
      ↓
构造 TotpItem
      ↓
加入数据库
      ↓
revision++
      ↓
saveDatabase()
      ↓
成功
      ↓
关闭 Add Page
      ↓
刷新 Home
      ↓
enqueuePush()
```

---

# 72. WebDAV 自动同步失败策略

例如：

```text
新增 TOTP
   ↓
本地保存成功
   ↓
Push 失败
```

结果：

```text
TOTP 正常存在
syncStatus = FAILED
提示用户
```

不能：

```text
删除刚刚新增的 TOTP
```

---

# 73. 同步重试

V1 不做无限自动重试。

建议：

- 当前操作失败后标记 Failed。
- 后续用户操作可再次触发 Push。
- 手动点击 Push 可以重试。
- 可以提供轻量级有限重试，例如 1~2 次，间隔逐渐增加。

不能：

```text
while(true) retry
```

---

# 74. 应用启动时 Pull 的安全顺序

正确：

```text
Start
 ↓
Privacy
 ↓
Encryption ready
 ↓
Load local
 ↓
Home render
 ↓
Background Pull
```

不要：

```text
Start
 ↓
Pull
 ↓
等待网络
 ↓
才能进入 Home
```

---

# 75. 深色模式

必须支持：

- Light
- Dark

避免使用硬编码：

```text
Color.White
Color.Black
```

尽量使用主题资源 / 系统语义颜色。

验证码数字需要确保：

- 足够对比度
- 深色模式可读
- 倒计时清晰

---

# 76. UI 动画

动画保持克制。

允许：

- 页面转场
- 卡片出现
- 倒计时轻量变化

不建议：

- 每秒大幅缩放验证码
- 复杂粒子动画
- 高频动画导致耗电

---

# 77. 性能要求

首页有 50~100 个 TOTP 时仍应：

- UI 流畅
- Timer 不创建大量对象
- 不重复读取磁盘
- 不重复做 PBKDF2
- 不重复建立 WebDAV 请求

---

# 78. 加密性能策略

PBKDF2 是昂贵操作。

禁止：

```text
每生成一次 TOTP
→ PBKDF2
```

正确：

```text
用户解锁数据库
      ↓
derive key
      ↓
内存使用
```

TOTP 每次刷新只进行 HMAC 计算。

---

# 79. Derived Key 生命周期

建议：

```text
App startup
   ↓
user enters key
   ↓
derive AES key
   ↓
memory only
```

不要：

```text
derive key
↓
save derived key
↓
下次直接读取
```

---

# 80. 加密数据库解锁模型

V1 可以采用：

```text
启动应用
 ↓
输入加密密钥
 ↓
解密数据库
 ↓
进入首页
```

如果产品后续决定提供：

- 生物识别
- 系统锁屏
- 自动解锁

必须作为独立安全设计，不允许自行存储主密钥绕过当前安全模型。

---

# 81. 自动锁定（V2）

V1 可以不实现。

未来可以：

```text
App 后台超过 N 分钟
       ↓
清理内存数据库引用
       ↓
重新要求用户验证
```

---

# 82. 测试策略

至少分四类：

```text
Unit Test
Integration Test
UI Test
Security Test
```

---

# 83. Unit Test：TOTP

必须使用 RFC 6238 官方测试向量。

覆盖：

- SHA1
- SHA256
- SHA512
- 6 digits
- 8 digits
- 多个 timestamp

---

# 84. Unit Test：Base32

测试：

- 正常 Secret
- 小写
- 空格
- Padding
- 非法字符
- 空 Secret
- 极短 Secret

---

# 85. Unit Test：OTP URI

测试：

```text
完整 URI
无 issuer
有 issuer
无 algorithm
无 digits
无 period
非法 scheme
缺少 secret
URL encode
中文 issuer
特殊字符 account
```

---

# 86. Security Test：Crypto

必须覆盖：

### 正常

```text
encrypt
→ decrypt
→ original
```

### 错误密钥

```text
encrypt
→ wrong key
→ decrypt failed
```

### 数据篡改

```text
modify ciphertext
→ decrypt failed
```

### Tag 篡改

```text
modify authentication tag
→ decrypt failed
```

### Nonce 处理

确保每次新加密不会固定使用同一个 nonce。

---

# 87. Security Test：本地存储

检查：

```text
搜索应用目录
```

不应发现：

```text
secret 明文
master key 明文
password 明文
完整 JSON 明文
```

---

# 88. Security Test：日志

测试代码和运行日志中不能出现：

```text
TOTP Secret
Encryption Secret
WebDAV Password
Derived AES Key
Authorization Header
```

---

# 89. Integration Test：WebDAV

至少测试：

- 正常连接
- 错误用户名
- 错误密码
- 404
- 403
- 500
- 网络超时
- 服务器断开
- 上传成功
- 下载成功
- 下载损坏文件
- 远程文件为空

---

# 90. Integration Test：同步

测试场景：

### 场景 A

```text
新增
→ 本地成功
→ Push 成功
```

### 场景 B

```text
新增
→ 本地成功
→ Push 失败
```

预期：

```text
本地仍有数据
```

### 场景 C

```text
删除
→ 本地成功
→ Push 失败
```

预期：

```text
本地删除仍然生效
```

---

# 91. Integration Test：Pull

测试：

```text
远程有效
→ Pull 成功
```

```text
远程错误密钥加密
→ Pull 失败
→ 本地不变
```

```text
远程文件损坏
→ Pull 失败
→ 本地不变
```

```text
远程 revision 较旧
→ 不覆盖本地较新数据
```

---

# 92. UI Test：首次启动

首次打开：

```text
显示隐私政策
```

不同意：

```text
不能进入主功能
```

同意：

```text
进入加密初始化
```

---

# 93. UI Test：生成密钥

验证：

```text
点击生成
→ 输入框出现密钥
→ 点击复制
→ Clipboard 正确
```

---

# 94. UI Test：添加 TOTP

扫描：

```text
QR
→ Parser
→ Confirmation
→ Save
→ Home
```

手动：

```text
Input
→ Validate
→ Save
→ Home
```

---

# 95. UI Test：复制验证码

点击验证码：

```text
Code
→ Clipboard
→ Toast
```

同时确认：

- 复制内容正确。
- 不复制 issuer。
- 不复制空格。

例如：

显示：

```text
123 456
```

Clipboard 内容：

```text
123456
```

---

# 96. UI Test：删除

```text
Long Press
→ Confirm
→ Delete
→ Local Save
→ UI Refresh
→ Auto Push
```

---

# 97. AI Coding 开发顺序

严格按以下顺序实施。

## Phase 0

工程基础：

```text
Project
Theme
Routing
Constants
Error
Result
Logger
```

完成后先编译。

---

## Phase 1

数据模型：

```text
TotpItem
DatabaseModel
WebDavConfig
SettingsModel
SyncModel
```

完成后加入类型测试。

---

## Phase 2

Crypto：

```text
CryptoService
Encrypted File Format
Random Secret
PBKDF2
AES-GCM
```

必须先写单元测试。

**Crypto 未通过测试，不进入下一阶段。**

---

## Phase 3

Storage：

```text
StorageService
LocalRepository
Atomic Write
Load
Save
Replace
Change Key
```

完成：

```text
App restart
→ database restored
```

---

## Phase 4

TOTP：

```text
Base32
TOTP
Parser
Countdown
```

使用 RFC 测试向量。

---

## Phase 5

首页：

```text
HomeViewModel
HomePage
TotpCard
Clipboard
```

---

## Phase 6

添加：

```text
AddTotpViewModel
AddTotpPage
ScanPage
Scan Kit
```

---

## Phase 7

WebDAV：

```text
WebDavService
WebDavPage
Test Connection
PUT
GET
PROPFIND
```

---

## Phase 8

Sync：

```text
SyncService
Queue
Auto Push
Auto Pull
Revision
Conflict Check
```

---

## Phase 9

Privacy：

```text
PrivacyDialog
PrivacyPolicyPage
Privacy Version
Startup State Machine
```

---

## Phase 10

测试与修复：

```text
Unit
Integration
UI
Security
Performance
```

---

# 98. 每个 Phase 的 AI 工作方式

AI 不应该一次生成整个项目。

每次只允许完成一个明确模块。

推荐：

```text
1. 读取已有代码
2. 检查当前目录
3. 检查 SDK/API
4. 实现当前模块
5. 编译
6. 修复编译错误
7. 添加测试
8. 总结改动
9. 再进入下一阶段
```

---

# 99. AI 修改代码的限制

AI 不得擅自：

- 修改已经确定的数据格式
- 删除安全校验
- 将 Service 逻辑移动到 Page
- 用明文存储代替加密
- 用假数据绕过 API
- 用 `any` 大规模规避类型系统
- 为了编译成功注释掉功能
- 删除失败处理
- 删除测试

如果 SDK API 与文档示例不一致：

```text
优先查看实际 SDK 类型定义
```

而不是猜 API 名称。

---

# 100. AI 生成代码时的最小变更原则

每次修改尽量：

```text
1 个功能
1~3 个文件
```

不要一次性修改大量文件。

例如实现复制功能，只修改：

```text
ClipboardService
TotpCard
HomeViewModel
```

而不是同时重构：

```text
Home
Storage
Crypto
WebDAV
Settings
```

---

# 101. 编译要求

每个 Phase 结束必须：

```text
Build
↓
No compile errors
↓
No type errors
↓
No lint errors
```

至少确保：

- TypeScript / ArkTS 类型正确
- import 正确
- async / await 正确
- Promise 返回值一致
- enum / union type 一致

---

# 102. 类型安全要求

优先：

```ts
type
interface
enum
union
```

避免：

```ts
any
unknown as SomeType
```

只有无法避免的平台 API 边界可以进行最小范围类型转换。

---

# 103. 异步代码规范

禁止大量：

```ts
setTimeout(() => {
  ...
}, 1000)
```

模拟异步。

真实异步应该使用：

```ts
async / await
```

同步队列统一由 SyncService 管理。

---

# 104. 错误处理规范

禁止：

```ts
try {
  ...
} catch {}
```

必须：

```ts
try {
  ...
} catch (error) {
  Logger.error(...)
  return {
    success: false,
    error: ...
  }
}
```

同时注意日志不得泄露敏感数据。

---

# 105. UI 层错误处理

Service：

```text
Result<T>
```

ViewModel：

```text
AppError
→
UI Message
```

Page：

```text
显示 Toast / Dialog / State
```

不要让 Page 解析 HTTP Status、Crypto Error。

---

# 106. Service 单例策略

以下 Service 可以采用应用级单例：

- TotpService
- CryptoService
- StorageService
- WebDavService
- SyncService

但要注意：

- 不要在单例中无限缓存数据。
- 不要在单例中持久化主密钥。
- 不要让全局状态无法释放。

---

# 107. 初始化依赖

建议：

```text
AppContext
   ↓
ServiceContainer
   ├── CryptoService
   ├── StorageService
   ├── WebDavService
   ├── SyncService
   └── TotpService
```

Service 初始化顺序：

```text
Crypto
 ↓
Storage
 ↓
WebDAV
 ↓
Sync
```

---

# 108. AppContainer

可以定义：

```ts
interface AppContainer {
  cryptoService: CryptoService;
  storageService: StorageService;
  webDavService: WebDavService;
  syncService: SyncService;
  totpService: TotpService;
  clipboardService: ClipboardService;
}
```

ViewModel 通过依赖注入取得 Service。

不要：

```ts
new CryptoService()
```

散落在每个 Page。

---

# 109. 数据一致性

以下不变量必须始终成立：

### 不变量 1

如果 Home 显示一个 TOTP，则本地加密数据库中必须存在对应 Item。

### 不变量 2

如果本地数据库保存成功，则重新启动 App 必须能够恢复。

### 不变量 3

如果 Pull 失败，本地数据不能被破坏。

### 不变量 4

如果 Push 失败，本地数据不能被回滚。

### 不变量 5

没有正确加密密钥，不能解密 TOTP 数据。

---

# 110. 用户可恢复性

必须允许：

```text
卸载 / 更换设备
→ 重新安装
→ 同意隐私政策
→ 配置 WebDAV
→ 输入原加密密钥
→ Pull
→ 恢复
```

因此：

- 加密格式必须稳定。
- 数据版本必须明确。
- KDF 参数必须写入文件。
- WebDAV 文件不能依赖本地设备状态才能解密。

---

# 111. 数据导出能力

V1 不需要实现明文导出。

如果未来实现导出：

默认禁止：

```text
Export JSON
```

除非用户显式确认。

因为明文导出文件包含全部 TOTP Secret。

---

# 112. 安全风险说明

AI 在实现时必须特别注意：

### 风险 1：弱密码

用户可能输入：

```text
123456
password
```

因此必须使用 KDF。

### 风险 2：密钥丢失

没有恢复机制。

UI 必须明确说明。

### 风险 3：WebDAV 泄漏

即使 WebDAV 被读取：

```text
攻击者只能获得加密文件
```

不能直接获得 TOTP Secret。

### 风险 4：日志泄漏

禁止敏感数据进入日志。

---

# 113. 推荐常量

```ts
export const APP_NAME = '源时';

export const APP_NAME_EN = 'SourceTime';

export const DATABASE_FILE_NAME = 'totp.db.enc';

export const CURRENT_SCHEMA_VERSION = 1;

export const CURRENT_PRIVACY_POLICY_VERSION = '1.0';

export const DEFAULT_TOTP_PERIOD = 30;

export const DEFAULT_TOTP_DIGITS = 6;

export const DEFAULT_TOTP_ALGORITHM: TotpAlgorithm = 'SHA1';

export const DEFAULT_WEBDAV_DIRECTORY = '/SourceTime/';
```

---

# 114. 推荐的开发检查表

## 工程

- [ ] 项目可构建
- [ ] 路由正常
- [ ] 主题正常
- [ ] 深色模式正常

## 隐私

- [ ] 首次启动弹窗
- [ ] 未同意无法使用
- [ ] 版本变更可再次确认

## 加密

- [ ] 随机密钥
- [ ] PBKDF2
- [ ] AES-GCM
- [ ] Salt
- [ ] Nonce
- [ ] Tag
- [ ] 错误密钥失败
- [ ] 篡改数据失败

## TOTP

- [ ] SHA1
- [ ] SHA256
- [ ] SHA512
- [ ] 6 位
- [ ] 8 位
- [ ] period
- [ ] QR
- [ ] 手动输入

## 存储

- [ ] 加密文件
- [ ] 原子写入
- [ ] 重启恢复
- [ ] 改密钥
- [ ] 明文扫描无结果

## WebDAV

- [ ] Test
- [ ] PUT
- [ ] GET
- [ ] PROPFIND
- [ ] Basic Auth
- [ ] HTTPS
- [ ] 失败处理

## 同步

- [ ] Auto Push
- [ ] Auto Pull
- [ ] Manual Push
- [ ] Manual Pull
- [ ] Queue
- [ ] Revision
- [ ] 不覆盖最新本地数据

---

# 115. 最终验收标准

SourceTime V1 只有在以下条件全部满足时才认为完成。

## 功能

- [ ] 用户可以同意隐私政策进入应用
- [ ] 用户可以生成加密密钥
- [ ] 用户可以复制生成的密钥
- [ ] 用户可以手动输入密钥
- [ ] 用户可以添加 TOTP
- [ ] 用户可以扫码添加
- [ ] 用户可以手动添加
- [ ] 验证码实时刷新
- [ ] 点击验证码可以复制
- [ ] 可以删除
- [ ] WebDAV 可以测试
- [ ] WebDAV 可以 Push
- [ ] WebDAV 可以 Pull
- [ ] 新增可自动 Push
- [ ] 删除可自动 Push
- [ ] 启动可自动 Pull

## 安全

- [ ] TOTP Secret 本地加密
- [ ] WebDAV 文件加密
- [ ] WebDAV Password 安全保存
- [ ] 没有主密钥明文落盘
- [ ] 没有 Secret 明文日志
- [ ] Pull 失败不会覆盖本地数据
- [ ] Crypto Tag 验证有效
- [ ] 篡改检测有效

## 稳定性

- [ ] 重启后数据可恢复
- [ ] 断网可正常使用核心功能
- [ ] 网络失败不影响本地操作
- [ ] 快速连续修改不会导致同步竞争
- [ ] 远程损坏文件不会破坏本地数据

---

# 116. 推荐的 AI Prompt 模板

后续让 AI 实现某个模块时，建议统一使用以下 Prompt 结构：

```text
你正在实现 SourceTime HarmonyOS 项目。

请严格遵守：
1. SourceTime AI Coding 实施规范。
2. SourceTime 产品实现规划文档 V1.1。
3. 当前已经存在的项目代码和目录结构。

本次只实现：
[填写具体功能]

要求：
- 不修改无关模块。
- 不破坏已有 API。
- 不改变已确定的数据格式。
- 不降低安全等级。
- 不使用明文存储敏感数据。
- 不打印 Secret、Key、Password。
- 页面只负责 UI。
- 业务逻辑放到 ViewModel / Service。
- 使用实际 HarmonyOS SDK 支持的 API。
- 如果当前 SDK API 与示例不同，以实际 SDK 类型定义为准。
- 实现后检查编译错误和类型错误。
- 给出修改文件列表。
- 给出测试方法。
```

---

# 117. 推荐的 AI 开发节奏

不要一次要求：

```text
“把 SourceTime 全部写出来”
```

推荐：

```text
任务 01：工程初始化
任务 02：数据模型
任务 03：CryptoService
任务 04：StorageService
任务 05：TOTP
任务 06：Home
任务 07：Add
任务 08：Scan
任务 09：WebDAV
任务 10：Sync
任务 11：Privacy
任务 12：Tests
```

每个任务完成并验证后再进入下一个。

---

# 118. 第一阶段建议直接执行的任务

AI Coding 的第一个实际任务建议固定为：

```text
创建 SourceTime HarmonyOS 工程骨架。

只实现：
1. 项目目录
2. 页面路由
3. Model
4. Result
5. AppError
6. Constants
7. 基础 Theme
8. 空白 Home
9. 空白 Settings
10. 空白 Privacy 页面

暂时不要实现：
- Crypto
- TOTP
- WebDAV
- Scan
- Storage

要求：
- 项目能够编译
- 路由能够运行
- 不使用 mock 数据冒充真实业务
```

这样可以先建立稳定工程基础，再逐层加入高风险模块。

---

# 119. 第二阶段建议执行的任务

```text
实现 CryptoService。

要求：
1. 使用 HarmonyOS 当前 SDK 实际可用的 Crypto API。
2. 实现安全随机数。
3. 实现 PBKDF2-HMAC-SHA256。
4. 实现 AES-256-GCM。
5. 实现随机 Salt。
6. 实现随机 Nonce。
7. 实现完整性验证。
8. 定义加密文件格式 Version 1。
9. 增加正常加解密测试。
10. 增加错误密钥测试。
11. 增加密文篡改测试。
12. 不允许任何敏感数据日志。
```

---

# 120. 最终 AI 编码铁律

SourceTime 的 AI 实现永远遵循以下顺序：

```text
安全
 ↓
数据完整性
 ↓
业务正确性
 ↓
可维护性
 ↓
UI 体验
 ↓
性能优化
```

任何“方便”都不能成为降低安全性的理由。

特别是：

```text
为了方便
→ 明文存储
```

禁止。

```text
为了调试
→ 打印 Secret
```

禁止。

```text
为了赶进度
→ 跳过加密校验
```

禁止。

```text
为了兼容
→ 自动修改 Secret
```

禁止。

```text
为了编译
→ 大量使用 any
```

不推荐。

---

# 121. V1 技术基线

| 项目 | 基线 |
|---|---|
| 项目 | SourceTime / 源时 |
| 平台 | HarmonyOS |
| 语言 | ArkTS |
| 架构 | Page → ViewModel → Service → Repository |
| TOTP | RFC 6238 |
| Hash | SHA1 / SHA256 / SHA512 |
| OTP | 6 / 8 digits |
| Default Period | 30s |
| Encryption | AES-256-GCM |
| KDF | PBKDF2-HMAC-SHA256 |
| Random Secret | 256-bit |
| Storage | Encrypted Single File |
| Sync | WebDAV |
| Remote File | `totp.db.enc` |
| Sync Mode | Offline First |
| Auto Push | Add/Delete |
| Auto Pull | Startup, optional |
| Conflict | Revision / UpdatedAt check |
| Privacy | First-launch consent |
| License | MIT / Apache-2.0（二选一） |

---

# 122. 完成定义（Definition of Done）

一个模块只有同时满足以下条件才算完成：

```text
代码完成
+
类型检查通过
+
构建通过
+
异常路径处理完成
+
敏感数据检查完成
+
必要测试完成
+
没有引入无关修改
+
符合当前架构
```

最终目标不是“代码能跑”，而是：

> **SourceTime 能够在真实 HarmonyOS 设备上稳定运行，并且 TOTP 数据、加密密钥、WebDAV 凭据和同步流程在正确性与安全性上形成完整闭环。**
