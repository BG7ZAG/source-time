import { AppContextHolder } from './AppContextHolder';

/**
 * 把 Resource 文案解析成当前系统语言的字符串。
 *
 * ArkUI 属性（Text/Button/Toast/对话框）本身接受 Resource，应优先直接用 $r()；
 * 只有必须拿到 string 的场合才走这里（拼接、导出文本、只收 string 的 API）。
 * 依赖 EntryAbility 早期的 AppContextHolder.init()，在 UI 启动前调用会抛错。
 */
export class UiText {
  static of(resource: Resource, ...args: Array<string | number>): string {
    const manager = AppContextHolder.getContext().resourceManager;
    if (args.length === 0) {
      return manager.getStringSync(resource.id);
    }
    return manager.getStringSync(resource.id, ...args);
  }
}
