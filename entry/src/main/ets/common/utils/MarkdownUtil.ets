/** 一行 Markdown 的结构 */
export interface MdLine {
  type: string      // 'h1' | 'h2' | 'h3' | 'text' | 'li' | 'code' | 'blank'
  text: string
}

export class MarkdownParser {

  /** 把 markdown 解析成按行组织的结构 */
  static parseLines(md: string): MdLine[] {
    const result: MdLine[] = []
    if (!md) return result

    const lines = md.split('\n')
    let inCode = false
    let codeBuf = ''

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]

      // 代码块
      if (line.startsWith('```')) {
        if (inCode) {
          const code: MdLine = { type: 'code', text: codeBuf }
          result.push(code)
          codeBuf = ''
          inCode = false
        } else {
          inCode = true
        }
        continue
      }
      if (inCode) {
        codeBuf += (codeBuf ? '\n' : '') + line
        continue
      }

      // 空行
      if (line.trim() === '') {
        const blank: MdLine = { type: 'blank', text: '' }
        result.push(blank)
        continue
      }

      // 标题
      if (line.startsWith('### ')) {
        const item: MdLine = { type: 'h3', text: MarkdownParser.cleanInline(line.substring(4)) }
        result.push(item)
      } else if (line.startsWith('## ')) {
        const item: MdLine = { type: 'h2', text: MarkdownParser.cleanInline(line.substring(3)) }
        result.push(item)
      } else if (line.startsWith('# ')) {
        const item: MdLine = { type: 'h1', text: MarkdownParser.cleanInline(line.substring(2)) }
        result.push(item)
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        const item: MdLine = { type: 'li', text: MarkdownParser.cleanInline(line.substring(2)) }
        result.push(item)
      } else if (/^\d+\. /.test(line)) {
        // 有序列表：保留序号
        const item: MdLine = { type: 'li', text: MarkdownParser.cleanInline(line) }
        result.push(item)
      } else {
        const item: MdLine = { type: 'text', text: MarkdownParser.cleanInline(line) }
        result.push(item)
      }
    }

    if (inCode && codeBuf) {
      const item: MdLine = { type: 'code', text: codeBuf }
      result.push(item)
    }
    return result
  }

  /** 去掉行内 ** 和 ` 标记，保留文字 */
  private static cleanInline(line: string): string {
    let r = line.replace(/\*\*/g, '')
    r = r.replace(/`/g, '')
    return r
  }
}