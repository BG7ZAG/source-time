import { pasteboard } from '@kit.BasicServicesKit';
import { Result, ok, err } from '../types/Result';
import { AppErrorCode } from '../types/Errors';
import { Logger } from '../utils/Logger';

export class ClipboardService {
  async copyText(text: string): Promise<Result<void>> {
    try {
      const data = pasteboard.createPlainTextData(text);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.setData(data);
      return ok(undefined);
    } catch (error) {
      Logger.error('Clipboard copy failed');
      return err<void>(AppErrorCode.UNKNOWN, '复制失败');
    }
  }
}
