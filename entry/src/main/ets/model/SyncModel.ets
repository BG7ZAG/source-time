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
  STARTUP = 'STARTUP'
}

export interface SyncState {
  status: SyncStatus;
  lastSyncAt?: number;
  message?: string;
}
