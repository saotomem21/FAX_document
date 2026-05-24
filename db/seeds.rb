company = Company.find_or_create_by!(name: "株式会社ネクスリンク") do |record|
  record.plan_name = "スタンダードプラン"
  record.monthly_generation_limit = 500
  record.monthly_generation_count = 0
end

user = User.find_or_initialize_by(email: "demo@nexlink.example")
user.assign_attributes(
  company: company,
  name: "山田 太郎",
  department: "マーケティング部",
  password: "password",
  password_confirmation: "password"
)
user.save!

template_rows = [
  {
    title: "足場工事向け・電話訴求型",
    description: "足場工事の新規開拓に向け、電話での問い合わせを促進する構成。",
    company_name: "株式会社○○○○",
    service_name: "足場工事・仮設機材リースサービス",
    service_summary: "足場工事の設計・施工から仮設機材のリースまで、安全・迅速・低コストでトータルサポートします。",
    target_region: "関東一円対応可能",
    target: "工務店・リフォーム会社・外壁工事会社のご担当者様",
    purpose: "新規問い合わせ獲得",
    contact_methods: "電話・FAX返信",
    catch_copy: "急な足場手配でお困りの方へ！",
    strengths: "安全第一の施工管理、迅速対応、柔軟な日程調整、豊富な施工実績",
    urgency_reason: "足場がないと工事が開始できず、工程の遅延や追加コストが発生する可能性があります。",
    phone_number: "03-XXXX-XXXX",
    fax_number: "03-XXXX-XXXX",
    website_url: "https://www.example.jp",
    reception_hours: "平日 8:00〜18:00",
    address: "〒000-0000 東京都○○区○○町1-2-3",
    credibility: "累計施工実績5,000件以上\n安全管理を徹底",
    opt_out_notice: "本FAXがご不要な場合は、お手数ですがFAX番号をご記入の上ご返信ください。"
  },
  {
    title: "採用支援向け・資料請求型",
    description: "採用支援サービスの認知拡大と資料請求を目的とした構成。",
    service_name: "採用支援サービス",
    service_summary: "中小企業向けに求人票作成、応募者対応、採用広報をまとめて支援します。",
    target: "人事・採用ご担当者様",
    purpose: "資料請求の獲得",
    contact_methods: "FAX返信",
    strengths: "中小企業支援に特化、採用広報まで対応、初回相談無料",
    phone_number: "03-1234-5678",
    fax_number: "03-1234-5679"
  },
  {
    title: "ICTサービス紹介・興味喚起型",
    description: "ICTサービスの紹介と、興味を喚起するきっかけづくりを目的とした構成。",
    service_name: "ICTサービス",
    service_summary: "社内の紙・電話・表計算業務をクラウドでまとめ、担当者の作業負担を削減します。",
    target: "情報システム担当者",
    purpose: "興味喚起・情報提供",
    contact_methods: "Webフォーム",
    strengths: "短期導入、専任サポート、既存業務に合わせた設計",
    website_url: "https://www.nexlink.example"
  }
]

templates = template_rows.map do |attributes|
  Template.find_or_create_by!(company: company, title: attributes[:title]) do |template|
    template.assign_attributes(attributes.merge(user: user))
  end
end

manuscript_rows = [
  templates.first.attributes.symbolize_keys.slice(*Manuscript::FORM_FIELDS).merge(
    title: "足場工事向け・電話訴求型",
    status: "generated"
  ),
  templates.second.attributes.symbolize_keys.slice(*Manuscript::FORM_FIELDS).merge(
    title: "採用支援向け・資料請求型",
    status: "generated"
  ),
  templates.third.attributes.symbolize_keys.slice(*Manuscript::FORM_FIELDS).merge(
    title: "ICTサービス紹介・興味喚起型",
    status: "reviewing"
  ),
  {
    title: "オフィスサポート・コスト削減訴求型",
    service_name: "オフィスサポートサービス",
    service_summary: "備品調達や事務代行など、総務部門の定型業務をまとめて支援します。",
    target: "総務・管理部門ご担当者様",
    purpose: "問い合わせ・見積もり依頼",
    contact_methods: "電話",
    strengths: "一括対応、コスト削減、月額固定",
    status: "draft"
  }
]

manuscript_rows.each do |attributes|
  manuscript = Manuscript.find_or_initialize_by(company: company, title: attributes[:title])
  manuscript.assign_attributes(attributes.merge(user: user))
  manuscript.save!
  ManuscriptGenerationService.new(manuscript).generate! if manuscript.generated? && manuscript.manuscript_versions.empty?
end
