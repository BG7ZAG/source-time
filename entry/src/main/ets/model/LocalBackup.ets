import { DatabaseModel } from './DatabaseModel';

/**
 * 本机备份类型。
 *
 * - ENCRYPTED：与 WebDAV 推送完全相同的密文字节（含 STOT 文件头）；
 * - PLAIN：直接 UTF-8 JSON 明文，便于用户自行查看或迁移，但任何应用都可读取。
 */
export enum LocalBackupKind {
  ENCRYPTED = 'encrypted',
  PLAIN = 'plain'
}

/** 解析完成、等待用户确认导入的本机备份。 */
export interface LocalBackupPreview {
  kind: LocalBackupKind;
  database: DatabaseModel;
}