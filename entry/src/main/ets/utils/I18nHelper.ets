/**
 * I18nHelper.ets — i18n 工具函数
 *
 * 提供 printf 风格的字符串格式化，配合 resourceManager 使用。
 */

/**
 * 简单的 printf 风格格式化。
 * 支持 %s（字符串）和 %d（数字）。
 *
 * @param template 含 %s / %d 占位符的模板字符串
 * @param args 依次替换的参数
 * @returns 格式化后的字符串
 */
export function formatStr(template: string, ...args: (string | number)[]): string {
  let i = 0
  let result = ''
  let pos = 0
  while (pos < template.length) {
    if (template[pos] === '%' && pos + 1 < template.length) {
      const next = template[pos + 1]
      if ((next === 's' || next === 'd') && i < args.length) {
        result += String(args[i])
        i++
        pos += 2
        continue
      }
    }
    result += template[pos]
    pos++
  }
  return result
}
