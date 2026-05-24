class ManuscriptsController < ApplicationController
  def index
    @manuscripts = [
      {
        title: "介護施設向け見守りカメラ提案",
        service: "CareWatch Cloud",
        target: "介護施設の施設長",
        status: "生成済み",
        updated_at: "2026/05/24 09:40",
        score: "A4 PDF"
      },
      {
        title: "製造業向け勤怠DXキャンペーン",
        service: "ShiftPilot",
        target: "中小製造業の総務担当",
        status: "再生成待ち",
        updated_at: "2026/05/23 18:12",
        score: "編集指示あり"
      },
      {
        title: "地域工務店向け集客相談会",
        service: "Local Leads",
        target: "工務店代表者",
        status: "下書き",
        updated_at: "2026/05/22 11:05",
        score: "Step2"
      }
    ]

    @templates = [
      "介護業界向け 問い合わせ獲得",
      "BtoB 無料診断オファー",
      "地域限定 キャンペーン告知"
    ]
  end
end
