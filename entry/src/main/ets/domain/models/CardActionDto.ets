/** 卡片动作请求 DTO */
export interface CardActionDto {
  session_id: string
  card_id: string
  card_type: string
  option_key: string
  text: string
  client_id: string
  file_id?: string              // ⭐ 新增：remove_asset 用
}