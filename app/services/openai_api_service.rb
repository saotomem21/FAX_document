class OpenaiApiService
  class ApiKeyMissingError < StandardError; end
  class InvalidResponseError < StandardError; end

  def initialize(client: nil)
    @client = client || OpenAI::Client.new(api_key: ENV["OPENAI_API_KEY"])
  end

  def generate_manuscript_content(manuscript, edit_instruction: nil)
    raise ApiKeyMissingError, "OPENAI_API_KEY is not configured" if ENV["OPENAI_API_KEY"].blank?

    response = @client.chat.completions(
      parameters: {
        model: "gpt-4o-mini",
        temperature: 0.7,
        max_tokens: 600,
        messages: [
          {
            role: "system",
            content: "あなたは日本語のFAXDM原稿を作成するアシスタントです。入力されたサービス情報から、FAX原稿の本文と画像生成プロンプトを生成してください。"
          },
          {
            role: "user",
            content: openai_user_prompt(manuscript, edit_instruction)
          }
        ]
      }
    )

    content = response.dig("choices", 0, "message", "content")
    parsed = parse_response(content)

    unless parsed.is_a?(Hash) && parsed["generated_body"].present? && parsed["image_prompt"].present?
      raise InvalidResponseError, "OpenAI response is missing generated_body or image_prompt"
    end

    parsed
  end

  private

  def openai_user_prompt(manuscript, edit_instruction)
    fields = {
      title: manuscript.title,
      service_name: manuscript.service_name,
      service_summary: manuscript.service_summary,
      target: manuscript.target,
      purpose: manuscript.purpose,
      strengths: manuscript.strengths,
      urgency_reason: manuscript.urgency_reason,
      contact_methods: manuscript.contact_methods,
      phone_number: manuscript.phone_number,
      fax_number: manuscript.fax_number,
      email: manuscript.email,
      website_url: manuscript.website_url,
      reception_hours: manuscript.reception_hours,
      address: manuscript.address,
      credibility: manuscript.credibility,
      opt_out_notice: manuscript.opt_out_notice
    }

    <<~PROMPT
      次の情報を使って、FAXDM原稿として使える文章と画像生成プロンプトを日本語で作成してください。

      #{fields.map { |key, value| "#{key.to_s.humanize}: #{value.presence || 'なし'}" }.join("\n")}
      #{"編集指示: #{edit_instruction}" if edit_instruction.present?}

      出力は以下のJSON形式のみで行ってください。
      {
        "generated_body": "...",
        "image_prompt": "..."
      }

      generated_bodyにはFAXDM本文の要点、対象、目的、訴求ポイント、問い合わせ導線を含めてください。
      image_promptにはA4縦白黒FAXDMにふさわしい日本語プロンプトを出力してください。
    PROMPT
  end

  def parse_response(content)
    json = content.to_s.strip
    json = json.match(/\{.*\}/m)&.to_s || json
    JSON.parse(json)
  rescue JSON::ParserError => e
    raise InvalidResponseError, "OpenAI response could not be parsed as JSON: #{e.message}"
  end
end
