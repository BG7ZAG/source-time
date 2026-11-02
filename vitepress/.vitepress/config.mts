import { defineConfig } from 'vitepress'

// 源时 SourceTime 文档站配置（中英双语）
const REPO_URL = 'https://github.com/BG7ZAG/source-time/'

export default defineConfig({
  cleanUrls: true,
  lastUpdated: true,

  head: [
    ['meta', { name: 'theme-color', content: '#0A59F7' }],
    ['meta', { name: 'apple-mobile-web-app-capable', content: 'yes' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:title', content: '源时 SourceTime' }],
    ['meta', { property: 'og:description', content: '鸿蒙 TOTP 动态口令工具 · 本地离线优先 · WebDAV 端到端加密同步' }]
  ],

  locales: {
    // 简体中文（默认）
    root: {
      label: '简体中文',
      lang: 'zh-CN',
      title: '源时 SourceTime',
      description: '鸿蒙 TOTP 动态口令工具 · 本地离线优先 · WebDAV 端到端加密同步',
      themeConfig: {
        nav: [
          { text: '首页', link: '/' },
          { text: '指南', link: '/guide/introduction', activeMatch: '/guide/' }
        ],
        sidebar: {
          '/guide/': [
            {
              text: '开始',
              items: [
                { text: '项目介绍', link: '/guide/introduction' },
                { text: '快速开始', link: '/guide/getting-started' }
              ]
            },
            {
              text: '使用',
              items: [
                { text: '核心功能', link: '/guide/features' },
                { text: 'WebDAV 同步', link: '/guide/webdav-sync' },
                { text: '安全设计', link: '/guide/security' }
              ]
            },
            {
              text: '参考',
              items: [
                { text: '技术栈与架构', link: '/guide/architecture' },
                { text: '常见问题', link: '/guide/faq' }
              ]
            }
          ]
        },
        outline: { level: [2, 3], label: '本页目录' },
        docFooter: { prev: '上一篇', next: '下一篇' },
        lastUpdated: { text: '最后更新于', formatOptions: { dateStyle: 'short', timeStyle: 'medium' } },
        footer: {
          message: '本项目基于 MIT 协议开源 · 本地优先 · 隐私可控',
          copyright: 'Copyright © 2026 源时 SourceTime'
        },
        darkModeSwitchLabel: '外观',
        lightModeSwitchTitle: '切换到浅色模式',
        darkModeSwitchTitle: '切换到深色模式',
        sidebarMenuLabel: '目录',
        returnToTopLabel: '回到顶部',
        langMenuLabel: '切换语言',
        externalLinkIcon: true
      }
    },

    // English
    en: {
      label: 'English',
      lang: 'en-US',
      title: 'SourceTime',
      description: 'A HarmonyOS TOTP authenticator · Local-first · End-to-end encrypted WebDAV sync',
      themeConfig: {
        nav: [
          { text: 'Home', link: '/en/' },
          { text: 'Guide', link: '/en/guide/introduction', activeMatch: '/en/guide/' }
        ],
        sidebar: {
          '/en/guide/': [
            {
              text: 'Getting Started',
              items: [
                { text: 'Introduction', link: '/en/guide/introduction' },
                { text: 'Quick Start', link: '/en/guide/getting-started' }
              ]
            },
            {
              text: 'Usage',
              items: [
                { text: 'Features', link: '/en/guide/features' },
                { text: 'WebDAV Sync', link: '/en/guide/webdav-sync' },
                { text: 'Security', link: '/en/guide/security' }
              ]
            },
            {
              text: 'Reference',
              items: [
                { text: 'Tech Stack & Architecture', link: '/en/guide/architecture' },
                { text: 'FAQ', link: '/en/guide/faq' }
              ]
            }
          ]
        },
        outline: { level: [2, 3], label: 'On this page' },
        docFooter: { prev: 'Previous page', next: 'Next page' },
        lastUpdated: { text: 'Last updated', formatOptions: { dateStyle: 'short', timeStyle: 'medium' } },
        footer: {
          message: 'Open sourced under the MIT License · Local-first · Privacy-respecting',
          copyright: 'Copyright © 2026 SourceTime'
        },
        darkModeSwitchLabel: 'Appearance',
        lightModeSwitchTitle: 'Switch to light theme',
        darkModeSwitchTitle: 'Switch to dark theme',
        sidebarMenuLabel: 'Menu',
        returnToTopLabel: 'Return to top',
        langMenuLabel: 'Change language',
        externalLinkIcon: true
      }
    }
  },

  // 所有语言共享的主题配置
  themeConfig: {
    logo: '/logo.svg',
    socialLinks: [{ icon: 'github', link: REPO_URL }],
    search: {
      provider: 'local',
      options: {
        // 按 locale key 提供本地搜索文案，VitePress 会据当前页面语言选用
        locales: {
          root: {
            translations: {
              button: { buttonText: '搜索文档', buttonAriaLabel: '搜索文档' },
              modal: {
                displayDetails: '显示详情',
                resetButtonTitle: '清除查询条件',
                backButtonTitle: '关闭搜索',
                noResultsText: '无法找到相关结果',
                footer: {
                  selectText: '选择',
                  selectKeyAriaLabel: '回车',
                  navigateText: '切换',
                  navigateUpKeyAriaLabel: '上箭头',
                  navigateDownKeyAriaLabel: '下箭头',
                  closeText: '关闭',
                  closeKeyAriaLabel: 'Esc'
                }
              }
            }
          },
          en: {
            translations: {
              button: { buttonText: 'Search', buttonAriaLabel: 'Search' },
              modal: {
                displayDetails: 'Display detailed list',
                resetButtonTitle: 'Reset search',
                backButtonTitle: 'Close search',
                noResultsText: 'No results for',
                footer: {
                  selectText: 'to select',
                  selectKeyAriaLabel: 'Enter',
                  navigateText: 'to navigate',
                  navigateUpKeyAriaLabel: 'up',
                  navigateDownKeyAriaLabel: 'down',
                  closeText: 'to close',
                  closeKeyAriaLabel: 'Escape'
                }
              }
            }
          }
        }
      }
    }
  }
})