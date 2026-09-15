export class DateUtil {
  static nowMs(): number { return Date.now() }

  static elapsedSeconds(startMs: number): number {
    return (Date.now() - startMs) / 1000
  }

  static formatDuration(seconds: number): string {
    return `${seconds.toFixed(2)} 秒`
  }
}