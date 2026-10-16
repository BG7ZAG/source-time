export interface SettingsModel {
  privacyPolicyAccepted: boolean;
  privacyPolicyVersion: string;

  encryptionInitialized: boolean;

  webDavEnabled: boolean;
  autoPush: boolean;
  autoPullOnStart: boolean;

  /** 应用锁：冷启动与后台回前台时要求输入 PIN。 */
  appLockEnabled: boolean;
  /** PIN 的 PBKDF2 校验值与盐（base64），不保存明文。 */
  appLockPinHash: string;
  appLockPinSalt: string;

  lastSyncAt?: number;
}
