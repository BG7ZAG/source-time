/**
 * 多平台布局常量。
 *
 * 统一采用「内容最大宽度 + 居中」的静态约束：
 * - 手机（窗口宽度小于上限）完全不受影响；
 * - 2in1 窗口实时缩放时由框架按新宽度自动重算，无需监听窗口尺寸变化。
 * - 手表使用独立的小屏常量，由 DeviceAdapter 动态选择。
 */

/** 页面内容区最大宽度（vp）：超宽时内容列居中，两侧由极光底自然填充。 */
export const CONTENT_MAX_WIDTH: number = 680;

/** 手表页面内容区最大宽度（vp）。 */
export const WATCH_CONTENT_MAX_WIDTH: number = 200;

/** 弹出表单（居中气泡卡片）最大宽度（vp）。 */
export const OVERLAY_MAX_WIDTH: number = 560;

/** 长按卡片弹出的操作菜单宽度（vp）：不设宽度时系统按两列默认宽度排版，两个字的「删除」会被撑得很空。 */
export const MENU_WIDTH: number = 108;

/** 中心对话框（隐私确认、备份选择等）最大宽度（vp）。 */
export const DIALOG_MAX_WIDTH: number = 440;

/** 应用锁锁屏内容最大宽度（vp）。 */
export const LOCK_CONTENT_MAX_WIDTH: number = 420;

/** 手表应用锁锁屏内容最大宽度（vp）。 */
export const WATCH_LOCK_CONTENT_MAX_WIDTH: number = 180;

/** 双列网格所需的最小**窗口**宽度（vp）：分屏/悬浮窗把窗口拖窄后回落到单列，避免验证码被挤爆。 */
export const GRID_MIN_WIDTH: number = 600;
