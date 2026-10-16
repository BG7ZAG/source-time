/**
 * 宽屏（平板 / 2in1）布局常量。
 *
 * 统一采用「内容最大宽度 + 居中」的静态约束：
 * - 手机（窗口宽度小于上限）完全不受影响；
 * - 2in1 窗口实时缩放时由框架按新宽度自动重算，无需监听窗口尺寸变化。
 */

/** 页面内容区最大宽度（vp）：超宽时内容列居中，两侧由极光底自然填充。 */
export const CONTENT_MAX_WIDTH: number = 680;

/** 弹出表单（居中气泡卡片）最大宽度（vp）。 */
export const OVERLAY_MAX_WIDTH: number = 560;

/** 中心对话框（隐私确认、备份选择等）最大宽度（vp）。 */
export const DIALOG_MAX_WIDTH: number = 440;

/** 应用锁锁屏内容最大宽度（vp）。 */
export const LOCK_CONTENT_MAX_WIDTH: number = 420;
