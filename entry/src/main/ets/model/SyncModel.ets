export enum SyncStatus {
  IDLE = 'IDLE',
  PUSHING = 'PUSHING',
  PULLING = 'PULLING',
  SUCCESS = 'SUCCESS',
  FAILED = 'FAILED'
}

export enum SyncReason {
  MANUAL = 'MANUAL',
  ADD_TOTP = 'ADD_TOTP',
  DELETE_TOTP = 'DELETE_TOTP',
  CHANGE_SETTINGS = 'CHANGE_SETTINGS',
  KEY_CHANGED = 'KEY_CHANGED',
  STARTUP = 'STARTUP'
}

export interface SyncState {
  status: SyncStatus;
  lastSyncAt?: number;
  /** 面向用户的同步提示：Resource 走多语言资源，string 仅用于无需翻译的场景。 */
  message?: ResourceStr;
}
