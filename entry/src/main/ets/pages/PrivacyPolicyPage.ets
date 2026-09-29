import { router } from '@kit.ArkUI';

@Entry
@Component
struct PrivacyPolicyPage {
  build() {
    Column() {
      Row() {
        Text('< 返回')
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .onClick(() => router.back())
        Blank()
        Text('隐私政策')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('')
          .width(48)
      }
      .width('100%')
      .padding(16)

      Scroll() {
        Column({ space: 16 }) {
          Text('源时（SourceTime）隐私政策')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('版本：1.0')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')

          Text('更新日期：2026年9月29日')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')

          Divider()
            .width('100%')

          Text('一、引言')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('源时是一款本地优先的 TOTP（基于时间的一次性密码）验证器应用。我们高度重视您的隐私和数据安全。本隐私政策旨在说明我们如何收集、使用、存储和保护您的数据，以及您享有的权利。')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('二、数据收集与使用')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('2.1 我们不收集您的个人身份信息。源时不要求注册、登录，也不关联您的手机号码或邮箱。')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('2.2 您主动输入的数据包括：')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('  - TOTP 配置信息（发行方名称、账号、密钥、算法、位数、周期）')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('  - 加密密钥（用于保护本地数据）')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('  - WebDAV 连接配置（服务器地址、用户名、密码、远程路径）')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('2.3 上述数据仅存储在您的设备本地，不会自动发送到任何外部服务器。')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('三、数据存储与安全')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('3.1 所有 TOTP 数据均经过 AES-256-GCM 加密后存储在设备本地文件中。加密密钥由用户设置或由应用使用系统安全随机数生成器生成。')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('3.2 加密密钥通过 PBKDF2-HMAC-SHA256 派生为 256 位加密密钥，迭代次数为 100,000 次。')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('3.3 WebDAV 密码同样经过加密后存储在本地 Preferences 中，不会以明文形式保存。')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('3.4 应用不会在日志中输出加密密钥、TOTP Secret 或 WebDAV 密码等敏感信息。')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('四、数据共享与传输')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('4.1 源时不会主动向开发者或任何第三方服务器上传您的数据。')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('4.2 如果您配置了 WebDAV 同步，应用会将加密后的数据文件上传到您指定的 WebDAV 服务器。传输的内容始终为加密文件，WebDAV 服务器无法直接读取您的 TOTP 数据。')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('4.3 WebDAV 服务由您自行配置和管理，开发者不对 WebDAV 服务的安全性和可用性负责。')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('4.4 扫码功能仅在本地处理二维码内容，不会将扫描结果发送到任何外部服务。')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('五、用户权利')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('5.1 您有权随时删除应用中的所有 TOTP 配置数据。删除操作不可恢复。')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('5.2 您有权随时修改加密密钥。修改密钥时需要验证旧密钥，验证通过后应用会使用新密钥重新加密所有数据。')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('5.3 您有权随时启用或禁用 WebDAV 同步功能，有权随时清除已保存的 WebDAV 配置。')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('5.4 卸载应用将清除所有本地存储的数据，包括加密的 TOTP 数据库和设置信息。')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('六、重要提示')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('6.1 请妥善保管您的加密密钥。源时不提供服务器端密钥恢复能力，丢失密钥后将无法解密已加密的数据。')
            .fontSize(14)
            .fontColor('#E84026')
            .width('100%')

          Text('6.2 建议在设置加密密钥后立即将密钥备份到安全的位置（如密码管理器或离线存储）。')
            .fontSize(14)
            .fontColor('#E84026')
            .width('100%')

          Text('6.3 WebDAV 同步传输的是加密文件，但请确保您的 WebDAV 服务器使用 HTTPS 协议以防止传输过程中的中间人攻击。')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('七、隐私政策更新')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('7.1 本隐私政策可能随应用版本更新而修订。政策版本号记录在应用设置中，当版本发生重大变更时，应用将在启动时重新提示您确认。')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('7.2 您可以在设置 > 隐私政策中随时查看当前版本的隐私政策内容。')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('八、开源声明')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text('8.1 源时是一款开源应用，源代码可供审查。您可以通过审查源代码验证本隐私政策的各项声明。')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Divider()
            .width('100%')

          Text('如您对本隐私政策有任何疑问，请通过项目仓库提交 Issue 反馈。')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        .padding({ left: 16, right: 16, bottom: 32 })
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
