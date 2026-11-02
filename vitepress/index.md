---
layout: home

hero:
  name: 源时
  text: SourceTime
  tagline: 鸿蒙 TOTP 动态口令工具 · 本地离线优先 · WebDAV 端到端加密同步
  actions:
    - theme: brand
      text: 快速开始
      link: /guide/getting-started
    - theme: alt
      text: 项目介绍
      link: /guide/introduction

features:
  - icon: 🔐
    title: 离线优先 · 本地运算
    details: 查看、新增、删除验证码与修改加密密钥全部无需联网，断网也能正常使用。WebDAV 仅作为同步与备份能力，网络不是核心依赖。
  - icon: 🛡️
    title: 全程加密 · 隐私可控
    details: TOTP Secret 属于高敏感数据，本地一律经用户密钥加密后存储，绝不出现明文持久化、明文日志或明文上传。
  - icon: 🔑
    title: 用户掌控加密密钥
    details: 应用不内置固定主密钥，密钥由用户手动输入或一键随机生成（256-bit），可随时修改、复制，自主掌控。
  - icon: ☁️
    title: WebDAV 私有云同步
    details: 支持用户自建 WebDAV 服务器备份，同步文件先加密再上传，服务端永远只看到密文，每次推送生成带时间的快照。
  - icon: 📖
    title: 完全开源 · 透明可信
    details: 代码完全开源、无暗门、无统计、无埋点，安全可审计，拒绝闭源黑盒。基于 MIT 协议发布。
  - icon: ⚡
    title: 轻量简洁 · 原生鸿蒙
    details: 基于 HarmonyOS NEXT 原生开发（ArkTS / ArkUI），极简卡片式首页，体积小、功耗低，适配手机、平板、折叠屏。
---