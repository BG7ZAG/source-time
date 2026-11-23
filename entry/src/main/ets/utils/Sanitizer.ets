/**
 * 日志脱敏：写入磁盘与页面展示前统一调用。
 *
 * 只做「确定性」替换，不做模糊猜测，覆盖本项目可能落到日志里的机密形态：
 * 1) key=value / key: value 形式的密钥、口令、令牌（secret、password、token、authorization 等）；
 * 2) 长 base64 / hex 密文串（本地密文、WebDAV 密码密文、字面量密钥）；
 * 3) http(s) URL 一律抹掉主机与路径（保留协议头），既覆盖 URL 内嵌的 basic auth 凭据，
 *    也避免服务器地址进入可导出的日志。
 *
 * 替换值一律用 *** 占位，不做「保留首尾」的部分掩码——首尾字符同样属于机密片段。
 * 日志调用点仍应遵守「只记长度、不记明文」的约定（如 keyLen=/pwdLen=），本模块是最后一道兜底。
 */

const SECRET_KEY_VALUE: RegExp =
  /(secret|password|passwd|pwd|token|api[_-]?key|access[_-]?key|private[_-]?key|authorization|credential|bearer|signature)\s*[=:]\s*[^\s,;)"']+/gi;

const URL_PATTERN: RegExp = /(https?:\/\/)[^\s)"'，。；、]+/gi;

const BASE64_BLOB: RegExp = /[A-Za-z0-9+/]{24,}={0,2}/g;

/**
 * 返回脱敏后的文本（不修改入参）。
 * 顺序：先按「键名 + 值」整体替换，再抹掉 URL，最后兜底抹掉裸密文串，
 * 否则兜底规则可能先吃掉键值对里的值，导致键名规则失配。
 */
export function maskSensitive(text: string): string {
  let masked: string = text;
  masked = masked.replace(SECRET_KEY_VALUE, '$1=***');
  masked = masked.replace(URL_PATTERN, '$1***');
  masked = masked.replace(BASE64_BLOB, '***');
  return masked;
}
