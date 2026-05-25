module Ai
  class FaxPromptGenerator
    # Switch to false for production (strict safety) mode
    PRESENTATION_MODE = true

    def initialize(manuscript)
      @manuscript = manuscript
    end

    def generate!
      @manuscript.update!(status: "prompt_generating")

      begin
        result = if openai_enabled?
                  generate_with_openai
                else
                  generate_local_fallback
                end

        structure = result[:generated_structure]
        body_text = format_structure_as_text(structure)

        @manuscript.update!(
          generated_structure: structure,
          generated_body: body_text,
          status: "prompt_generated",
          prompt_generated_at: Time.current
        )
      rescue => e
        Rails.logger.error "Prompt generation failed: #{e.message}"
        @manuscript.update!(status: "failed")
        raise e
      end

      @manuscript
    end

    private

    def openai_enabled?
      ENV["OPENAI_API_KEY"].present?
    end

    def generate_with_openai
      client = OpenAI::Client.new(api_key: ENV["OPENAI_API_KEY"])

      fields = {
        service_name: @manuscript.service_name,
        target: @manuscript.target,
        purpose: @manuscript.purpose,
        contact_methods: @manuscript.contact_methods,
        catch_copy: @manuscript.catch_copy,
        strengths: @manuscript.strengths,
        service_summary: @manuscript.service_summary,
        urgency_reason: @manuscript.urgency_reason
      }

      rules = if PRESENTATION_MODE
               presentation_rules
             else
               production_rules
             end

      user_prompt = <<~PROMPT
        次の入力情報をもとに、FAXDMの構成案をJSONで作成してください。
        電話番号・FAX番号・メールアドレス・URL・住所は含めないでください（アプリ側で補完します）。

        【入力情報】（未入力の項目には値を補完しないでください）
        #{fields.map { |key, value| "#{key}: #{value.presence || '（未入力）'}" }.join("\n")}

        【出力フォーマット】
        必ず以下のJSONフォーマットのみで出力してください。

        {
          "generated_structure": {
            "target_label": "宛先呼びかけ（例：工務店の皆様へ）",
            "headline": "キャッチコピー",
            "subheadline": "サブ見出し（1行）",
            "problem_points": ["課題1", "課題2"],
            "solution_points": ["解決策1", "解決策2"],
            "service_items": ["サービス項目1", "サービス項目2"],
            "strengths": ["強み1", "強み2"],
            "cta": "CTA文言（例：まずはお電話でご相談ください）",
            "reply_form_fields": ["会社名", "ご担当者名", "電話番号", "FAX番号", "ご相談内容"],
            "footer_note": "配信停止案内（例：FAX不要の方は、配信停止欄よりご連絡ください）"
          }
        }
      PROMPT

      params = {
        model: "gpt-4o-mini",
        temperature: PRESENTATION_MODE ? 0.6 : 0.3,
        max_tokens: 1200,
        messages: [
          {
            role: "system",
            content: "あなたは日本国内のBtoB向けFAXDMの構成案をJSONで作成する専門家です。\n\n#{rules}"
          },
          {
            role: "user",
            content: user_prompt
          }
        ]
      }

      response = client.chat.completions.create(params)

      raw = normalize_response(response)
      raw_content = extract_content(raw)

      raise "OpenAI API returned empty response" if raw_content.blank?

      parsed = parse_json_response(raw_content)

      structure = parsed["generated_structure"]
      raise "OpenAI response is missing generated_structure" if structure.blank?

      structure = sanitize_structure(structure)
      structure["strengths"] ||= []

      { generated_structure: structure }
    end

    def presentation_rules
      <<~RULES
        【プレゼンテーションモード：FAXDM構成案の作成】
        あなたはFAXDMの構成案をJSONで作成します。これは社内プレゼン用の完成見本です。
        見た目の完成度とFAX広告らしさを優先してください。

        方針:
        1. 課題・解決策・強みを自然な広告調で表現する
        2. 以下の表現を使ってよい: 迅速対応、地域密着、ご相談歓迎、柔軟対応、豊富なラインナップ、現場に合わせてご提案、スムーズにサポート
        3. 問題点・解決策は各2〜3個、強みは2〜3個
        4. service_itemsはユーザー入力から抽出（なければ汎用的な項目）
        5. footer_noteは配信停止案内

        禁止事項（プレゼンでも使わない）:
        - No.1、顧客満足度No.1、業界No.1、ナンバー1
        - 最安値、必ず、完全保証
        - 根拠のない実績件数（累計〇件、導入〇社 など）
        - 電話番号、FAX番号、メールアドレス、URL、住所（アプリ側で補完）
        - 価格、割引、キャンペーン、特別価格
      RULES
    end

    def production_rules
      design_rules = fax_document_prompt
      <<~RULES
        【本番モード：安全なFAXDM構成案の作成】
        あなたはFAXDMの構成案をJSONで作成します。完成原稿の本文を生成するのではなく、レイアウト構成のみをJSONで出力してください。

        絶対ルール:
        1. ユーザー入力にない情報は絶対に追加しない
        2. 電話番号や連絡先情報はJSONに含めない（Rails側で描画する）
        3. 本文は生成しない。見出し・短い箇条書き・CTA見出しのみ
        4. 強み・ポイントは入力値がある場合のみ使う。なければ「ご相談ください」等の安全表現
        5. 問題点・解決策は各2〜3個まで
        6. service_itemsはユーザー入力の内容から抽出
        7. No.1・実績・価格・割引・キャンペーンは絶対に生成しない

        以下のFAXDMデザインルールも守ってください。
        #{design_rules}
      RULES
    end
    def generate_local_fallback
      service_name = @manuscript.service_name.presence || "サービス"
      headline = @manuscript.catch_copy.presence || "#{service_name}のご案内"
      subheadline = @manuscript.purpose.presence || ""

      strengths_input = @manuscript.strengths.to_s.split(/[、,、\n]/).map(&:strip).reject(&:blank?)

      if PRESENTATION_MODE
        # Presentation: richer fallback
        problem_points = ["情報収集に時間がかかる", "適切なサービス選びが難しい", "現場のニーズに合った提案がほしい"]
        solution_points = strengths_input.any? ?
          strengths_input.first(3).map.with_index { |s, i| ["ご相談ください", "ご提案いたします", "柔軟に対応いたします"][i] || s } :
          ["まずはお気軽にご相談ください", "現場に合わせてご提案いたします", "豊富なラインナップから選べます"]
        fallback_strengths = strengths_input.any? ? strengths_input : ["迅速対応", "地域密着", "柔軟なご提案"]
      else
        # Production: safe minimal fallback
        problem_points = strengths_input.any? ?
          strengths_input.first(2).map { |s| "#{s}に関するお悩み" } :
          ["情報収集に時間がかかる", "適切なサービス選びが難しい"]
        solution_points = strengths_input.any? ?
          strengths_input.last(2).map { |s| "#{s}に対応" } :
          ["ご相談ください", "ご提案いたします"]
        fallback_strengths = strengths_input
      end

      service_items = if @manuscript.service_summary.present?
                       @manuscript.service_summary.split(/[、,、\n]/).map(&:strip).reject(&:blank?).first(4)
                     else
                       [service_name]
                     end

      cta = if @manuscript.contact_methods.present?
             case @manuscript.contact_methods
             when /電話|TEL|お電話/i
               "まずはお電話でご相談ください"
             when /FAX|ファックス/i
               "このままFAXでご返信ください"
             when /Web|QR|サイト|URL/i
               "QRコードから詳細をご確認ください"
             when /メール|mail/i
               "メールでお問い合わせください"
             else
               "お気軽にお問い合わせください"
             end
            else
             "お気軽にお問い合わせください"
            end

      structure = {
        "target_label" => @manuscript.target.present? ? "#{@manuscript.target}の皆様へ" : "お客様各位",
        "headline" => headline,
        "subheadline" => subheadline,
        "problem_points" => problem_points,
        "solution_points" => solution_points,
        "service_items" => service_items,
        "strengths" => fallback_strengths,
        "cta" => cta,
        "reply_form_fields" => ["会社名", "ご担当者名", "電話番号", "FAX番号", "メールアドレス", "ご相談内容"],
        "footer_note" => "FAX不要の方は、配信停止欄よりご連絡ください"
      }

      { generated_structure: structure }
    end

    def format_structure_as_text(structure)
      return "" if structure.blank?

      s = structure.is_a?(String) ? JSON.parse(structure) : structure
      lines = []

      lines << "## #{s["target_label"]}" if s["target_label"].present?
      lines << "# #{s["headline"]}" if s["headline"].present?
      lines << s["subheadline"] if s["subheadline"].present?

      if s["problem_points"].present?
        lines << ""
        lines << "【課題】"
        Array(s["problem_points"]).each { |p| lines << "・#{p}" }
      end

      if s["solution_points"].present?
        lines << ""
        lines << "【解決策】"
        Array(s["solution_points"]).each { |p| lines << "・#{p}" }
      end

      if s["service_items"].present?
        lines << ""
        lines << "【サービス内容】"
        Array(s["service_items"]).each { |item| lines << "・#{item}" }
      end

      if s["strengths"].present?
        lines << ""
        lines << "【強み】"
        Array(s["strengths"]).each { |item| lines << "・#{item}" }
      end

      lines << ""
      lines << "【CTA】#{s["cta"]}" if s["cta"].present?
      lines << "【配信停止】#{s["footer_note"]}" if s["footer_note"].present?

      lines.join("\n")
    end

    def fax_document_prompt
      prompt_path = Rails.root.join("app/services/prompt/fax_document_prompt.md")
      @fax_document_prompt ||= File.read(prompt_path).strip
    end

    def normalize_response(response)
      return nil if response.nil?

      if response.respond_to?(:deep_to_h)
        begin
          response.deep_to_h
        rescue StandardError
          nil
        end
      elsif response.is_a?(Hash)
        response
      end
    end

    def extract_content(raw)
      return nil unless raw.is_a?(Hash)

      raw.dig("choices", 0, "message", "content") ||
        raw.dig(:choices, 0, :message, :content) ||
        raw["choices"]&.first&.dig("message", "content") ||
        raw[:choices]&.first&.dig(:message, :content)
    end

    def parse_json_response(content)
      json = content.to_s.strip
      json = json.match(/\{.*\}/m)&.to_s || json
      JSON.parse(json)
    rescue JSON::ParserError => e
      raise "OpenAI response could not be parsed as JSON: #{e.message}"
    end

    def sanitize_structure(structure)
      %w[problem_points solution_points service_items reply_form_fields strengths].each do |key|
        structure[key] = Array(structure[key]).reject(&:blank?)
        # Filter out prohibited content (No.1, pricing, real-looking phone numbers, etc.)
        structure[key] = structure[key].map { |v| filter_prohibited_content(v.to_s) }.reject(&:blank?)
      end
      %w[target_label headline subheadline cta footer_note].each do |key|
        structure[key] = filter_prohibited_content(structure[key].to_s.strip)
      end
      structure
    end

    PROHIBITED_PATTERNS = [
      /No\.?\s*1/i,
      /ナンバー\s*1/i,
      /顧客満足度.*[1１①]/,
      /[1１①]\s*位/,
      /特別割引/,
      /初回限定/,
      /今だけ/,
      /期間限定/,
      /0\d{1,4}-\d{4}-\d{4}/,          # phone: 0X-XXXX-XXXX or 0XXX-XX-XXXX
      /0\d{1,4}-\d{1,4}-\d{4}/,        # fax: 0X-XXX-XXXX
      /https?:\/\/[^\s]+/,             # URLs
      /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/, # emails
      /累計\s*\d+[万件以上]+/,
      /導入\s*\d+[社件以上]+/,
      /施工\s*\d+[件以上]+/,
      /\d{3}-\d{4}-\d{4}/,             # mobile: 090-XXXX-XXXX
    ].freeze

    def filter_prohibited_content(text)
      return "" if text.blank?
      PROHIBITED_PATTERNS.each do |pattern|
        if text.match?(pattern)
          return ""  # Drop the entire string if it contains prohibited content
        end
      end
      text
    end
  end
end