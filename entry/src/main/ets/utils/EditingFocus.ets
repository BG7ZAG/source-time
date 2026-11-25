import { UIContext } from '@kit.ArkUI';
import { Logger } from './Logger';

/**
 * 应用回到前台后系统才恢复输入法和焦点，调用方可用这个延时再清理一次。
 */
export const EDITING_FOCUS_RETRY_DELAY_MS: number = 150;

/**
 * 清掉界面上的输入焦点，软键盘会随之收起。
 *
 * 这里只走焦点：inputMethod.hideSoftKeyboard() 需要 ohos.permission.CONNECT_IME_ABILITY，
 * 该权限仅系统应用可用，普通应用调用会失败，不能作为兜底。
 */
export function dismissEditingFocus(uiContext: UIContext | undefined): void {
  if (uiContext === undefined) {
    return;
  }
  try {
    uiContext.getFocusController().clearFocus();
  } catch (error) {
    Logger.warn('Clearing input focus failed', 'App');
  }
}