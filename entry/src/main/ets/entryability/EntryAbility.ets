import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppContextHolder } from '../utils/AppContextHolder';
import { SettingsService } from '../service/SettingsService';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppContextHolder.init(this.context);
    hilog.info(DOMAIN, 'SourceTime', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'SourceTime', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'SourceTime', '%{public}s', 'Ability onWindowStageCreate');

    const settingsService: SettingsService = new SettingsService();
    const settings = settingsService.getSettings();

    let initialPage: string = 'pages/HomePage';
    if (!settings.privacyPolicyAccepted) {
      initialPage = 'pages/HomePage';
    } else if (!settings.encryptionInitialized) {
      initialPage = 'pages/SecurityPage';
    } else {
      initialPage = 'pages/HomePage';
    }

    windowStage.loadContent(initialPage, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'SourceTime', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'SourceTime', 'Succeeded in loading the content.');
    });

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'SourceTime', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'SourceTime', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'SourceTime', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'SourceTime', '%{public}s', 'Ability onBackground');
  }
}
