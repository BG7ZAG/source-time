/**
 * 远端备份文件条目（WebDAV 目录中的一个 .enc 快照文件）。
 *
 * 云端一律是**带日期时间**的快照：sourcetime-<日期时间>.enc（手动/自动推送均生成，互不覆盖）。
 */
export interface RemoteBackup {
  /** 文件名，例如 sourcetime-20261014-154512.enc。 */
  name: string;
  /** 服务端最后修改时间（毫秒）；服务端未返回时为 0。 */
  lastModified: number;
  /** 文件大小（字节）；未知时为 0。 */
  size: number;
}
