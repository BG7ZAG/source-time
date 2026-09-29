export interface SettingsModel {
  privacyPolicyAccepted: boolean;
  privacyPolicyVersion: string;

  encryptionInitialized: boolean;

  webDavEnabled: boolean;
  autoPush: boolean;
  autoPullOnStart: boolean;

  lastSyncAt?: number;
}
