import { ConfigurationConstant } from '@kit.AbilityKit';
import { uiMaterial } from '@kit.ArkUI';
import { colorFromText } from '../utils/ColorUtils';

/**
 * 鸿蒙 7「沉浸光感」设计语言的公共样式工厂。
 *
 * 材质策略：
 * - 优先使用 HarmonyOS 26 的沉浸式系统材质（ImmersiveMaterial）。
 *   它直接读取屏幕后方的真实像素做折射与高光，效果与系统弹层完全一致；
 *   这需要 module.json5 里 entry 模块配置 ohos.arkui.UIMaterial.state = enable。
 * - 若设备不支持（isImmersiveMaterialSupported() 为 false）或材质未生效，
 *   自动降级为自绘冰晶样式（半透明底色 + 高斯模糊 + 1px 高光边框 + 空间阴影）。
 *
 * 说明：ArkUI 的 shadow() 不接受 Resource 颜色，因此这里用运行时色深判断给出具体色值。
 */

let darkMode: boolean = false;
let immersiveMaterialReady: boolean = false;

/** 由 EntryAbility 在加载页面前（以及系统深浅色变化时）调用。 */
export function initGlassTheme(colorMode: ConfigurationConstant.ColorMode): void {
  darkMode = colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
}

/** 由 EntryAbility 在加载页面前探测设备是否支持沉浸式系统材质。 */
export function initImmersiveMaterialSupport(): void {
  try {
    immersiveMaterialReady = uiMaterial.isImmersiveMaterialSupported();
  } catch (error) {
    immersiveMaterialReady = false;
  }
}

/** 当前设备是否可用沉浸式系统材质（决定是否启用自绘冰晶降级样式）。 */
export function supportsImmersive(): boolean {
  return immersiveMaterialReady;
}

/** 当前是否为深色主题（由 initGlassTheme 同步，供状态栏图标配色等场景使用）。 */
export function isDarkMode(): boolean {
  return darkMode;
}

let materialRegular: uiMaterial.Material | undefined = undefined;
let materialThin: uiMaterial.Material | undefined = undefined;
let materialInteractive: uiMaterial.Material | undefined = undefined;

/**
 * 常规厚度材质：用于 TOTP 卡片等内容面积较大的冰晶卡片。
 * @param enabled 传入 false（或设备不支持）时返回 undefined，属性即回到无材质效果，
 *   组件随即使用自绘冰晶降级样式。
 */
export function cardMaterial(enabled: boolean): uiMaterial.Material | undefined {
  if (!enabled || !immersiveMaterialReady) {
    return undefined;
  }
  if (materialRegular === undefined) {
    materialRegular = new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: true
    });
  }
  return materialRegular;
}

/** 薄材质：用于胶囊按键等轻量控件。 */
export function thinMaterial(enabled: boolean): uiMaterial.Material | undefined {
  if (!enabled || !immersiveMaterialReady) {
    return undefined;
  }
  if (materialThin === undefined) {
    materialThin = new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      applyShadow: true
    });
  }
  return materialThin;
}

/** 带交互形变与光感反馈的薄材质：用于可点击的悬浮控件（FAB）。 */
export function interactiveMaterial(enabled: boolean): uiMaterial.Material | undefined {
  if (!enabled || !immersiveMaterialReady) {
    return undefined;
  }
  if (materialInteractive === undefined) {
    materialInteractive = new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      applyShadow: true,
      interactive: true,
      lightEffect: { color: undefined }
    });
  }
  return materialInteractive;
}

export interface ShadowSpec {
  radius: number;
  color: string;
  offsetX: number;
  offsetY: number;
}

/** 无阴影占位：用于让「有/无光晕」两种状态使用同一类型，避免三元表达式类型推断分歧。 */
export function noShadow(): ShadowSpec {
  return { radius: 0, color: '#00000000', offsetX: 0, offsetY: 0 };
}

/** 输入框获焦时的主色光晕。 */
export function focusGlowShadow(): ShadowSpec {
  if (darkMode) {
    return { radius: 12, color: '#665B9DFF', offsetX: 0, offsetY: 2 };
  }
  return { radius: 12, color: '#590A59F7', offsetX: 0, offsetY: 2 };
}

/** 分段选择器选中项的轻微浮起阴影。 */
export function segmentShadow(): ShadowSpec {
  if (darkMode) {
    return { radius: 8, color: '#4D000000', offsetX: 0, offsetY: 2 };
  }
  return { radius: 8, color: '#1F0A1E3C', offsetX: 0, offsetY: 2 };
}

/** 冰晶卡片的 Z 轴柔和空间阴影。 */
export function glassCardShadow(): ShadowSpec {
  if (darkMode) {
    return { radius: 18, color: '#66000000', offsetX: 0, offsetY: 6 };
  }
  return { radius: 16, color: '#1A0A1E3C', offsetX: 0, offsetY: 5 };
}

/** 分组卡片（设置页等）稍浅的阴影。 */
export function glassGroupShadow(): ShadowSpec {
  if (darkMode) {
    return { radius: 22, color: '#4D000000', offsetX: 0, offsetY: 8 };
  }
  return { radius: 18, color: '#0D0A1E3C', offsetX: 0, offsetY: 7 };
}

/** 顶部磨砂胶囊按钮 / 悬浮球的投影。 */
export function glassPillShadow(): ShadowSpec {
  if (darkMode) {
    return { radius: 14, color: '#40000000', offsetX: 0, offsetY: 4 };
  }
  return { radius: 14, color: '#140A1E3C', offsetX: 0, offsetY: 4 };
}

/** 主色发光按钮的能量光晕。 */
export function glowButtonShadow(): ShadowSpec {
  if (darkMode) {
    return { radius: 16, color: '#665B9DFF', offsetX: 0, offsetY: 5 };
  }
  return { radius: 14, color: '#590A59F7', offsetX: 0, offsetY: 5 };
}

/** 发行方柔光微立体图标衬底的投影。 */
export function avatarShadow(): ShadowSpec {
  if (darkMode) {
    return { radius: 10, color: '#4D000000', offsetX: 0, offsetY: 3 };
  }
  return { radius: 10, color: '#1A0A1E3C', offsetX: 0, offsetY: 3 };
}

/**
 * 由发行方配色派生「双色柔光微立体」图标衬底：主色 + 同色系更亮的收束光。
 * 返回值直接用于 linearGradient 的 colors 字段。
 */
export function avatarGradientColors(key: string): Array<[string, number]> {
  const base: string = colorFromText(key);
  const light: string = lightenHex(base, 0.34);
  return [[light, 0.0], [base, 1.0]];
}

/**
 * 倒计时阶段：0=常规（品牌蓝） 1=警示（琥珀） 2=危险（红）。
 * 阈值集中在 countdownStage() 里，避免各组件各写一套判断。
 */
export type CountdownStage = 0 | 1 | 2;

/** 剩余秒数 → 阶段：最后 3 秒转红，最后 8 秒转琥珀（30 秒周期下约 1/4 处开始预警）。 */
export function countdownStage(remaining: number): CountdownStage {
  if (remaining <= 3) {
    return 2;
  }
  if (remaining <= 8) {
    return 1;
  }
  return 0;
}

/** 倒计时光轨 / 环形进度的能量渐变。 */
export function trackGradientColors(stage: CountdownStage): Array<[string, number]> {
  if (stage === 2) {
    // 纯红色阶：渐变两端都留在红相区间，避免起点偏橙导致整体看起来像橙色
    if (darkMode) {
      return [['#FF7A70', 0.0], ['#FF3B30', 1.0]];
    }
    return [['#FF5A52', 0.0], ['#D01B1B', 1.0]];
  }
  if (stage === 1) {
    if (darkMode) {
      return [['#FFD60A', 0.0], ['#FF9F0A', 1.0]];
    }
    return [['#FFD426', 0.0], ['#FF9500', 1.0]];
  }
  if (darkMode) {
    return [['#6ED0FF', 0.0], ['#5B9DFF', 1.0]];
  }
  return [['#64B5F6', 0.0], ['#0A59F7', 1.0]];
}

/**
 * 口令文字的流光渐变（Text.shaderStyle）。
 * 深色下用「冰蓝 → 主蓝」，浅色下用「主蓝 → 亮蓝」；进入危险区切为琥珀→危险色。
 * 注意 shaderStyle 优先级高于 fontColor，且与 NumericTextTransition 不兼容。
 */
export function codeGradientColors(stage: CountdownStage): Array<[string, number]> {
  if (stage === 2) {
    if (darkMode) {
      return [['#FF9A8E', 0.0], ['#FF453A', 1.0]];
    }
    return [['#FF5A52', 0.0], ['#C81818', 1.0]];
  }
  if (stage === 1) {
    if (darkMode) {
      return [['#FFE9A8', 0.0], ['#FF9F0A', 1.0]];
    }
    return [['#FFC02E', 0.0], ['#F57C00', 1.0]];
  }
  if (darkMode) {
    return [['#D6ECFF', 0.0], ['#7FB6FF', 1.0]];
  }
  return [['#0A59F7', 0.0], ['#3892FF', 1.0]];
}

/**
 * 标题文字的流光渐变：力度比口令更收敛，避免抢走验证码的视觉重心。
 */
export function titleGradientColors(): Array<[string, number]> {
  if (darkMode) {
    return [['#FFFFFF', 0.0], ['#9CC4FF', 1.0]];
  }
  return [['#0A2540', 0.0], ['#0A59F7', 1.0]];
}

/**
 * 粒子爆发色阶（鸿蒙蓝 → 冰蓝）。
 * 返回定长二元组以匹配 ArkUI 的 ParticleTuple<ResourceColor, ResourceColor>：
 * 若声明为 string[]，编译期无法证明长度为 2，会报「source may have fewer」。
 */
export function particleColorRange(): [string, string] {
  if (darkMode) {
    return ['#5B9DFF', '#6ED0FF'];
  }
  return ['#0A59F7', '#64B5F6'];
}

function lightenHex(hex: string, amount: number): string {
  const normalized: string = hex.startsWith('#') ? hex.substring(1) : hex;
  if (normalized.length !== 6) {
    return hex;
  }
  const red: number = parseInt(normalized.substring(0, 2), 16);
  const green: number = parseInt(normalized.substring(2, 4), 16);
  const blue: number = parseInt(normalized.substring(4, 6), 16);
  const mix = (channel: number): number => {
    const lifted: number = channel + (255 - channel) * amount;
    return Math.min(255, Math.max(0, Math.round(lifted)));
  };
  return '#' + toHexPair(mix(red)) + toHexPair(mix(green)) + toHexPair(mix(blue));
}

function toHexPair(value: number): string {
  const hex: string = value.toString(16);
  return hex.length === 1 ? '0' + hex : hex;
}

/** 环形进度 / 光轨的轨道底色（随主题切换需要具体色值）。 */
export function trackBaseColor(): string {
  if (darkMode) {
    return '#335B9DFF';
  }
  return '#1F0A59F7';
}

/** 环形进度当前进度的描边色。 */
export function trackProgressColor(stage: CountdownStage): string {
  if (stage === 2) {
    return darkMode ? '#FF453A' : '#E01F1F';
  }
  if (stage === 1) {
    return darkMode ? '#FF9F0A' : '#FF9500';
  }
  return darkMode ? '#5B9DFF' : '#0A59F7';
}

/** 环形进度内圈柔光色（低透明度模拟发光）。 */
export function trackGlowColor(stage: CountdownStage): string {
  if (stage === 2) {
    return darkMode ? '#33FF5F52' : '#26FF3B30';
  }
  if (stage === 1) {
    return darkMode ? '#33FF9F0A' : '#26FF9500';
  }
  return darkMode ? '#335B9DFF' : '#260A59F7';
}

/** 环形倒计时中央秒数的颜色（随阶段从主文本色过渡到琥珀、红）。 */
export function countdownTextColor(stage: CountdownStage): string {
  if (stage === 2) {
    return darkMode ? '#FF6B60' : '#D81B1B';
  }
  if (stage === 1) {
    return darkMode ? '#FF9F0A' : '#FF9500';
  }
  return darkMode ? '#E6FFFFFF' : '#E6000000';
}

/** 状态脉冲灯的三种状态色。 */
export function statusDotColor(status: string): string {
  if (status === 'success') {
    return darkMode ? '#30D158' : '#34C759';
  }
  if (status === 'failed') {
    return darkMode ? '#FF5F52' : '#FF3B30';
  }
  return darkMode ? '#8E8E93' : '#8C8C93';
}

/** 磨砂胶囊按键底色。 */
export function frostedPillColor(): string {
  return darkMode ? '#401F2E4D' : '#66FFFFFF';
}
