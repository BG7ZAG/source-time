export function nowSeconds(): number {
  return Math.floor(Date.now() / 1000);
}

export function nowMilliseconds(): number {
  return Date.now();
}

export function calculateRemainingSeconds(timestampMilliseconds: number, period: number): number {
  if (period <= 0) {
    return 0;
  }
  return period - (Math.floor(timestampMilliseconds / 1000) % period);
}
