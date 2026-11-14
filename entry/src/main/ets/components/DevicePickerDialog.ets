import { PeerDevice } from '../service/DistributedConfigService';
import { DIALOG_MAX_WIDTH } from '../constants/LayoutConstants';
import { glassCardShadow } from '../theme/GlassStyle';

/**
 * 「同步到手表」的设备选择弹窗（冰晶模态卡片）。
 *
 * 一次性配置包只推给选中的那一台，避免组内有平板/第二台手机时被一起覆盖。
 * 列表由调用方排序（手表优先），默认选中调用方给的上次目标或第一项。
 */
@CustomDialog
export struct DevicePickerDialog {
  controller?: CustomDialogController;
  devices: PeerDevice[] = [];
  /** 默认选中的 deviceId；为空时选第一项。 */
  selected: string = '';
  onConfirm: (deviceId: string) => void = () => {};
  onCancel: () => void = () => {};

  @State current: string = '';

  aboutToAppear(): void {
    if (this.selected.length > 0) {
      this.current = this.selected;
    } else if (this.devices.length > 0) {
      this.current = this.devices[0].deviceId;
    }
  }

  /** 设备类型标签：手表优先展示为「手表」，其余按手机/平板/电脑归类。 */
  private typeLabel(type: string): ResourceStr {
    if (type === 'wearable') {
      return $r('app.string.device_type_wearable');
    }
    if (type === 'phone') {
      return $r('app.string.device_type_phone');
    }
    if (type === 'tablet') {
      return $r('app.string.device_type_tablet');
    }
    if (type === '2in1' || type === 'pc') {
      return $r('app.string.device_type_pc');
    }
    return $r('app.string.device_type_other');
  }

  @Builder
  deviceRow(item: PeerDevice) {
    Row({ space: 12 }) {
      Radio({ value: item.deviceId, group: 'devicePicker' })
        .checked(this.current === item.deviceId)
        .onChange((isChecked: boolean) => {
          if (isChecked) {
            this.current = item.deviceId;
          }
        })

      Column({ space: 4 }) {
        Text(item.deviceName)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(this.typeLabel(item.deviceType))
          .fontSize(11.5)
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(16)
    .backgroundColor(this.current === item.deviceId
      ? $r('app.color.field_background')
      : $r('app.color.card_background'))
    .onClick(() => {
      this.current = item.deviceId;
    })
  }

  build() {
    Column({ space: 16 }) {
      Column()
        .width(36)
        .height(4)
        .borderRadius(2)
        .backgroundColor($r('app.color.divider'))

      Column({ space: 4 }) {
        Text($r('app.string.security_device_picker_title'))
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Text($r('app.string.security_device_picker_subtitle', this.devices.length))
          .fontSize(11.5)
          .fontColor($r('app.color.text_tertiary'))
      }
      .alignItems(HorizontalAlign.Center)
      .width('100%')

      List({ space: 6 }) {
        ForEach(this.devices, (item: PeerDevice) => {
          ListItem() {
            this.deviceRow(item)
          }
        }, (item: PeerDevice) => item.deviceId)
      }
      .width('100%')
      .height(Math.min(this.devices.length, 4) * 62)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      Row({ space: 12 }) {
        Button($r('app.string.common_cancel'))
          .layoutWeight(1)
          .height(46)
          .borderRadius(23)
          .fontSize(15)
          .backgroundColor($r('app.color.pill_background'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => this.onCancel())

        Button($r('app.string.security_device_picker_confirm'))
          .layoutWeight(1)
          .height(46)
          .borderRadius(23)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .enabled(this.current.length > 0)
          .linearGradient({
            angle: 90,
            colors: [[$r('app.color.brand'), 0.0], [$r('app.color.brand_secondary'), 1.0]]
          })
          .fontColor($r('app.color.fab_foreground'))
          .shadow({ radius: 12, color: '#590A59F7', offsetX: 0, offsetY: 4 })
          .onClick(() => this.onConfirm(this.current))
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ maxWidth: DIALOG_MAX_WIDTH })
    .padding({ left: 18, right: 18, top: 14, bottom: 22 })
    .borderRadius(28)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow(glassCardShadow())
  }
}
