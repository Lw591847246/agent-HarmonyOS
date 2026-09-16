export class JsonUtil {
  static safeParse<T>(text: string): T | null {
    try {
      return JSON.parse(text) as T
    } catch {
      return null
    }
  }

  static safeStringify(obj: Object): string {
    try {
      return JSON.stringify(obj)
    } catch {
      return ''
    }
  }
}