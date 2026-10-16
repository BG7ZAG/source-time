import { pasteboard } from '@kit.BasicServicesKit';
import { Result, ok, err } from '../types/Result';
import { AppErrorCode } from '../types/Errors';
import { Logger } from '../utils/Logger';

export class ClipboardService {
  async copyText(text: string): Promise<Result<void>> {
    return this.copyWithShareOption(text, undefined);
  }

  async copySensitiveText(text: string): Promise<Result<void>> {
    return this.copyWithShareOption(text, pasteboard.ShareOption.LOCALDEVICE);
  }

  private async copyWithShareOption(text: string, shareOption?: pasteboard.ShareOption): Promise<Result<void>> {
    try {
      const data: pasteboard.PasteData = pasteboard.createPlainTextData(text);
      if (shareOption !== undefined) {
        const property: pasteboard.PasteDataProperty = data.getProperty();
        property.shareOption = shareOption;
        data.setProperty(property);
      }
      const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.setData(data);
      return ok(undefined);
    } catch (error) {
      Logger.error('Clipboard copy failed');
      return err<void>(AppErrorCode.UNKNOWN, $r('app.string.error_copy_failed'));
    }
  }
}
