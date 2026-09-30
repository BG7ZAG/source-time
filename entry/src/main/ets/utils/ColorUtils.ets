/**
 * 从任意字符串稳定派生一个颜色，用于发行方首字母头像等场景。
 * 输出 #RRGGBB 字符串（ResourceColor 可直接使用），深浅色主题下对比度都足够。
 */
export function colorFromText(input: string): string {
  const text: string = input.length > 0 ? input : 'SourceTime';
  let hash: number = 5381;
  for (let i = 0; i < text.length; i++) {
    hash = ((hash << 5) + hash + text.charCodeAt(i)) >>> 0;
  }
  const hue: number = hash % 360;
  return hslToHex(hue, 0.58, 0.5);
}

function hslToHex(h: number, s: number, l: number): string {
  const c: number = (1 - Math.abs(2 * l - 1)) * s;
  const x: number = c * (1 - Math.abs(((h / 60) % 2) - 1));
  const m: number = l - c / 2;
  let r: number = 0;
  let g: number = 0;
  let b: number = 0;
  if (h < 60) {
    r = c;
    g = x;
  } else if (h < 120) {
    r = x;
    g = c;
  } else if (h < 180) {
    g = c;
    b = x;
  } else if (h < 240) {
    g = x;
    b = c;
  } else if (h < 300) {
    r = x;
    b = c;
  } else {
    r = c;
    b = x;
  }
  const channel = (v: number): string => {
    const n: number = Math.min(255, Math.max(0, Math.round((v + m) * 255)));
    const hex: string = n.toString(16);
    return hex.length === 1 ? '0' + hex : hex;
  };
  return '#' + channel(r) + channel(g) + channel(b);
}
