export interface WebDavConfig {
  enabled: boolean;
  baseUrl: string;
  username: string;
  password: string;
  remotePath: string;
  autoPush: boolean;
  autoPullOnStart: boolean;
}
