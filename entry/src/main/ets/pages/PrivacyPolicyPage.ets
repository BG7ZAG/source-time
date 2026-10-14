import { router } from '@kit.ArkUI';
import { AuroraBackground } from '../components/AuroraBackground';
import {
  frostedPillColor,
  glassGroupShadow,
  glassPillShadow
} from '../theme/GlassStyle';

/**
 * 隐私政策页（鸿蒙 7 版）：冰晶章卡片 + 灰色矢量章节图标。
 */
@Entry
@Component
struct PrivacyPolicyPage {
  @Builder
  header() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Image($r('app.media.ic_back'))
          .width(21)
          .height(21)
          .fillColor($r('app.color.text_primary'))
      }
      .width(42)
      .height(42)
      .borderRadius(21)
      .backgroundColor(frostedPillColor())
      .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
      .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
      .shadow(glassPillShadow())
      .onClick(() => router.back())

      Blank()

      Text('隐私政策')
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))

      Blank()

      Text('')
        .width(42)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
  }

  /** 章节卡片：双色柔光图标 + 标题 + 正文段落。 */
  @Builder
  sectionCard(icon: Resource, title: string, paragraphs: string[]) {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          Image(icon)
            .width(17)
            .height(17)
            .fillColor($r('app.color.text_secondary'))
        }
        .width(34)
        .height(34)
        .borderRadius(12)
        .backgroundColor($r('app.color.scrim'))
        .border({ width: 1, color: $r('app.color.divider'), style: BorderStyle.Solid })

        Text(title)
          .fontSize(15.5)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Divider()
        .color($r('app.color.divider'))
        .width('100%')

      ForEach(paragraphs, (line: string) => {
        Text(line)
          .fontSize(13.5)
          .lineHeight(22)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
      }, (line: string, index: number) => title + index.toString())
    }
    .width('100%')
    .padding(18)
    .borderRadius(24)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow(glassGroupShadow())
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  noticeCard(paragraphs: string[]) {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Image($r('app.media.ic_warning'))
          .width(17)
          .height(17)
          .fillColor($r('app.color.danger'))
        Text('重要提示')
          .fontSize(15.5)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.danger'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      ForEach(paragraphs, (line: string) => {
        Text(line)
          .fontSize(13.5)
          .lineHeight(22)
          .fontColor($r('app.color.danger'))
          .width('100%')
      }, (line: string, index: number) => 'notice' + index.toString())
    }
    .width('100%')
    .padding(18)
    .borderRadius(24)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .border({ width: 1, color: $r('app.color.brand_container'), style: BorderStyle.Solid })
    .shadow(glassGroupShadow())
    .alignItems(HorizontalAlign.Start)
  }

  pageTransition() {
    PageTransitionEnter({ type: RouteType.Push, duration: 250, curve: Curve.EaseOut })
      .slide(SlideEffect.Right)
    PageTransitionExit({ type: RouteType.Push, duration: 250, curve: Curve.EaseIn })
      .slide(SlideEffect.Left)
    PageTransitionEnter({ type: RouteType.Pop, duration: 250, curve: Curve.EaseOut })
      .slide(SlideEffect.Left)
    PageTransitionExit({ type: RouteType.Pop, duration: 250, curve: Curve.EaseIn })
      .slide(SlideEffect.Right)
  }

  build() {
    // @Entry 页面的 build 只能有唯一根节点，且必须是容器组件；
    // AuroraBackground 是自定义组件，故由 Stack 作为根承载它。
    Stack() {
      AuroraBackground() {
        Column() {
          this.header()

          Scroll() {
            Column({ space: 14 }) {
              // 标题区
              Column({ space: 6 }) {
                Text('源时（SourceTime）隐私政策')
                  .fontSize(19)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                  .width('100%')

                Row({ space: 8 }) {
                  Text('版本 2.0')
                    .fontSize(11.5)
                    .fontColor($r('app.color.brand_on_container'))
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .borderRadius(10)
                    .backgroundColor($r('app.color.brand_container'))

                  Text('更新日期：2026年10月14日')
                    .fontSize(11.5)
                    .fontColor($r('app.color.text_tertiary'))
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding({ top: 4, bottom: 2 })

              this.sectionCard($r('app.media.ic_security'), '一、引言与适用范围', [
                '源时（SourceTime）是一款本地优先的鸿蒙（HarmonyOS）TOTP 动态口令工具，基于 RFC 6238 在设备本地生成一次性验证码。',
                '本政策适用于应用内的全部数据处理行为，包括数据收集、本地加密存储、运行日志、WebDAV 同步、剪贴板使用与数据删除。',
                '本政策仅涵盖源时应用自身；你在应用中自行配置的 WebDAV 服务器，以及操作系统提供的备份、剪贴板等系统级能力不在本政策范围内，其数据处理适用相应服务方的规则。',
                '源时是开源应用（MIT 协议），源代码可供审查，你可以通过审查代码验证本政策的各项声明。'
              ])

              this.sectionCard($r('app.media.ic_box'), '二、我们收集与处理的数据', [
                '源时不收集你的个人身份信息，不要求注册、登录，也不关联手机号或邮箱。',
                '源时不自发采集设备硬件标识（如 IMEI、OAID）、位置、通讯录、通话记录、应用使用统计或崩溃上报信息。',
                '你主动输入并保存在本地的数据包括：TOTP 配置（发行方、账号、密钥、算法、位数、周期）、加密密钥、WebDAV 连接配置（服务器地址、用户名、密码、远程路径与同步开关）。',
                '为支持同步判断，应用会在本地加密库中保存一个由应用自行生成的随机 UUID（deviceId），它不是任何系统硬件标识符。',
                '除你主动启用的 WebDAV 同步与系统备份外，上述数据仅存储在你的设备本地，不会发送到任何外部服务器。'
              ])

              this.sectionCard($r('app.media.ic_privacy'), '三、权限说明', [
                '源时仅申请两项系统权限：网络权限（ohos.permission.INTERNET）与相机权限（ohos.permission.CAMERA）。',
                '网络权限仅用于你主动配置并启用的 WebDAV 同步；不启用 WebDAV 时应用不进行网络通信。',
                '相机权限仅在你主动进入扫码页时、在前台使用（when: inuse），用于扫描 otpauth 二维码以录入 TOTP 配置。',
                '源时不申请存储读写、位置、麦克风、电话、短信、通讯录等其它权限。'
              ])

              this.sectionCard($r('app.media.ic_security'), '四、数据的本地存储与加密', [
                '全部口令数据以单个加密文件 totp.db.enc 的形式保存在应用私有目录中。',
                '数据在落盘前经 AES-256-GCM 加密：使用随机 12 字节 Nonce 与 16 字节认证标签，读取时必须校验认证标签。',
                '加密密钥由你的主密钥经 PBKDF2-HMAC-SHA256 派生：随机 16 字节 Salt、迭代 100,000 次、生成 256 位密钥。',
                '写入采用原子写：先写入临时文件、同步到磁盘、校验尺寸后再重命名覆盖，失败时保留原文件。',
                '应用设置保存在应用私有存储中；其中 WebDAV 密码经加密后保存，而 WebDAV 服务器地址、用户名、远程路径与各项开关以明文形式保存在应用私有空间内。',
                '应用不会在文件中以明文形式保存加密密钥、TOTP 密钥或 WebDAV 密码。'
              ])

              this.sectionCard($r('app.media.ic_privacy'), '五、加密密钥与安全', [
                '加密密钥由系统关键资产存储（Asset Store Kit）托管，应用不以明文文件方式保存该密钥。',
                '托管密钥在设备首次解锁后可用（DEVICE_FIRST_UNLOCKED）。',
                '应用会在启动时从系统关键资产存储取回密钥，用于本地数据的静默加解密。',
                '源时不提供服务器端密钥找回能力；密钥一旦丢失，已加密数据将无法解密。'
              ])

              this.noticeCard([
                '6.1 请妥善保管加密密钥。源时不提供服务器端密钥恢复能力，丢失密钥后将无法解密已加密的数据。',
                '6.2 建议在设置密钥后立即备份到安全位置（如密码管理器或离线存储）。',
                '6.3 WebDAV 同步传输的是加密文件，但请确保服务器使用 HTTPS，防止传输过程中的中间人攻击。'
              ])

              this.sectionCard($r('app.media.ic_log'), '七、运行日志与诊断信息', [
                '源时会在本地留存运行日志，用于故障排查与问题诊断，并同时输出到系统日志（hilog）。',
                '日志以 NDJSON 文件（sourcetime_logs.ndjson）形式保存在应用私有目录，最多保留 500 条，超出后丢弃最旧条目。',
                '日志仅保存在本地，不会上传到任何服务器。',
                '日志在写入与展示前会经过脱敏处理，将密钥、密码、令牌、授权信息等敏感字段替换为 ***。',
                '脱敏基于规则匹配，属尽力而为，不构成对敏感信息绝不出现的绝对保证。',
                '你可以在「设置 > 运行日志」中查看、按级别过滤、复制（内容已脱敏）或清空日志。',
                '清空日志只删除日志文件，不影响你的口令数据与 WebDAV 同步配置。'
              ])

              this.sectionCard($r('app.media.ic_cloud'), '八、WebDAV 同步与远程备份', [
                '仅当你自行配置并启用 WebDAV 时，源时才会通过你指定的服务器地址进行网络通信。',
                '上传的内容是你本地已完成 AES-256-GCM 加密的库文件（密文），服务器方只能看到密文，无法直接读取你的 TOTP 数据。',
                '每次推送都会生成一个带时间戳的快照文件（sourcetime-YYYYMMDD-HHMMSS.enc），不覆盖历史快照。',
                '应用默认在远端保留最近 10 份快照并自动清理更旧的快照，只会删除应用自身命名的备份文件，不影响服务器上的其它文件。',
                '同步触发时机包括：你手动发布或拉取、新增或删除口令后、设置变更后、加密密钥变更后，以及应用启动时自动拉取（后两项自动行为可在设置中关闭）。',
                '手动拉取时，你可以从远端备份列表中选择要恢复的快照，经二次确认后以该快照覆盖本地数据；手动拉取不提供回滚保护，请谨慎操作。',
                '启动时的自动拉取带有回滚保护：若远端数据版本低于本地，应用会拒绝覆盖。',
                '若同步失败，应用不会回滚你本地的操作。',
                '网络请求使用 HTTP Basic 鉴权，凭据仅放在请求头中、不写入日志；请务必使用 HTTPS，以降低凭据在传输中被截获的风险。',
                'WebDAV 服务器由你自行搭建与管理，开发者不运营任何用于接收你数据的服务器，也不对其安全性与可用性负责。'
              ])

              this.sectionCard($r('app.media.ic_edit'), '九、剪贴板与会话数据', [
                '当你点击验证码卡片时，当前验证码会被复制到系统剪贴板。',
                '生成加密密钥后，应用支持将密钥一键复制到系统剪贴板。',
                '在运行日志页，应用支持将（已脱敏的）日志复制到系统剪贴板。',
                '系统剪贴板为系统级共享区域，其它应用可能读取其中的内容；复制加密密钥后请留意此风险，并在使用后及时清除剪贴板。'
              ])

              this.sectionCard($r('app.media.ic_sync'), '十、系统备份与恢复', [
                '源时允许参与操作系统的备份与恢复流程，因此你的应用数据可能被纳入系统级备份。',
                '该行为由操作系统与设备厂商的云服务决定，具体纳入范围与存储位置以其平台说明为准，开发者无法控制。'
              ])

              this.sectionCard($r('app.media.ic_cloud'), '十一、数据共享与第三方组件', [
                '源时不会向开发者或任何第三方服务器上传你的数据；你自行配置的 WebDAV 服务器是唯一的外部数据接收方。',
                '应用不集成任何第三方统计、广告或崩溃上报 SDK，不进行数据埋点。',
                '应用所使用的均为鸿蒙系统能力，包括网络（NetworkKit）、扫码（ScanKit）、加密（CryptoArchitectureKit）、系统关键资产存储（AssetStoreKit）与系统剪贴板，不涉及第三方数据处理服务。'
              ])

              this.sectionCard($r('app.media.ic_doc'), '十二、数据留存与删除', [
                '本地加密库（totp.db.enc）会一直保留，直至你主动删除。',
                '运行日志最多保留 500 条，你可随时在运行日志页清空。',
                '远端快照由你的 WebDAV 服务器保存，应用默认保留最近 10 份；你也可以在服务器侧自行删除。',
                '应用设置（含隐私政策确认状态、同步配置等）保存在应用私有存储中，随卸载或清除数据移除。',
                '在应用内删除口令数据后不可恢复。',
                '当本地加密文件无法被当前密钥解密时，应用会将其隔离重命名（.orphan-<时间戳>）后保留，而不是物理删除；只有「忘记密钥」流程会在你确认后物理删除本地密文。',
                '卸载应用通常会清除应用的私有数据；但如果你曾让应用参与系统备份，相关数据可能被系统备份恢复。'
              ])

              this.sectionCard($r('app.media.ic_person'), '十三、你的权利', [
                '查询：你可以随时在应用内查看已保存的口令与各项配置。',
                '更正：你可以编辑或重新录入任意 TOTP 项、修改 WebDAV 配置。',
                '删除：你可以删除口令数据、清空运行日志、清除 WebDAV 配置。',
                '撤回同意：在首次启动的隐私确认弹窗中选择「不同意」，应用将退出且不处理你的数据。',
                '密钥与同步控制：你可以随时更改加密密钥、启用或停用 WebDAV 同步。'
              ])

              this.sectionCard($r('app.media.ic_person'), '十四、未成年人保护', [
                '源时面向具备完全民事行为能力的用户，不面向未满 14 周岁的儿童提供独立服务。',
                '应用不主动收集未成年人的个人信息；如监护人发现未成年人未经同意使用了本应用，可通过下方渠道联系我们。'
              ])

              this.sectionCard($r('app.media.ic_edit'), '十五、隐私政策的更新与同意机制', [
                '本政策可能随应用版本更新而修订。',
                '政策版本号记录在应用设置中，你可以在本页顶部与「设置 > 隐私政策」中随时查看当前版本与更新日期。',
                '当你不同意更新后的政策时，可以停止使用并卸载应用。'
              ])

              this.sectionCard($r('app.media.ic_doc'), '十六、适用法律与争议解决', [
                '本政策适用中华人民共和国法律。',
                '因本政策产生的争议，双方应首先友好协商解决；协商不成的，可向有管辖权的人民法院提起诉讼。'
              ])

              this.sectionCard($r('app.media.ic_about'), '十七、联系我们', [
                '如对本政策或你的数据有任何疑问或请求，请通过项目仓库提交 Issue：https://github.com/BG7ZAG/source-time 。',
                '你也可以通过审查开源代码（MIT 协议）进一步了解数据处理细节。'
              ])

              Text('如对本政策有任何疑问，请通过项目仓库提交 Issue 反馈。')
                .fontSize(12)
                .textAlign(TextAlign.Center)
                .fontColor($r('app.color.text_tertiary'))
                .width('100%')
                .padding({ top: 6, bottom: 24 })
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .align(Alignment.TopStart)  // 内容不足一屏时不被 Scroll 垂直居中
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
