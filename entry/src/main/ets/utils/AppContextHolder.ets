import { common } from '@kit.AbilityKit';

export class AppContextHolder {
  private static appContext: common.UIAbilityContext | null = null;

  static init(context: common.UIAbilityContext): void {
    AppContextHolder.appContext = context;
  }

  static getContext(): common.UIAbilityContext {
    if (AppContextHolder.appContext === null) {
      throw new Error('AppContext not initialized');
    }
    return AppContextHolder.appContext;
  }
}
