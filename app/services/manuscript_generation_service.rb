require "erb"
require "fileutils"

class ManuscriptGenerationService
  def initialize(manuscript, edit_instruction: nil)
    @manuscript = manuscript
    @edit_instruction = edit_instruction.to_s.strip.presence
    @ai_result = nil
  end

  def generate!
    FileUtils.mkdir_p(image_dir)
    FileUtils.mkdir_p(pdf_dir)

    @manuscript.assign_attributes(
      status: "generated",
      generated_body: generated_body,
      image_prompt: image_prompt
    )
    @manuscript.save!

    version_number = @manuscript.next_version_number
    svg_path = image_dir.join("manuscript_#{@manuscript.id}_v#{version_number}.svg")
    pdf_path = pdf_dir.join("manuscript_#{@manuscript.id}_v#{version_number}.pdf")

    File.write(svg_path, svg_markup)
    File.binwrite(pdf_path, SimplePdfRenderer.render(@manuscript, version_number: version_number))

    @manuscript.update!(
      generated_svg_path: svg_path.relative_path_from(Rails.root).to_s,
      generated_pdf_path: pdf_path.relative_path_from(Rails.root).to_s
    )

    @manuscript.manuscript_versions.create!(
      version_number: version_number,
      edit_instruction: @edit_instruction,
      generated_body: @manuscript.generated_body,
      image_prompt: @manuscript.image_prompt,
      generated_svg_path: @manuscript.generated_svg_path,
      generated_pdf_path: @manuscript.generated_pdf_path
    )

    @manuscript.company.increment!(:monthly_generation_count)
    @manuscript
  end

  private

  def generated_body
    if openai_enabled?
      ai_result.fetch("generated_body")
    else
      local_generated_body
    end
  end

  def image_prompt
    if openai_enabled?
      ai_result.fetch("image_prompt")
    else
      local_image_prompt
    end
  end

  def openai_enabled?
    ENV["OPENAI_API_KEY"].present?
  end

  def ai_result
    @ai_result ||= OpenaiApiService.new.generate_manuscript_content(@manuscript, edit_instruction: @edit_instruction)
  end

  def local_generated_body
    [
      headline,
      "対象: #{@manuscript.target}",
      "目的: #{@manuscript.purpose}",
      "訴求ポイント: #{benefit_points.join(' / ')}",
      "問い合わせ導線: #{@manuscript.contact_methods}",
      @edit_instruction.present? ? "再生成指示: #{@edit_instruction}" : nil
    ].compact.join("\n")
  end

  def local_image_prompt
    "A4縦、白黒FAXDM、#{@manuscript.service_name}、#{@manuscript.target}向け、" \
      "強い見出し、問い合わせ導線は#{@manuscript.contact_methods}、読みやすい高コントラスト"
  end

  def storage_root
    Rails.env.test? ? Rails.root.join("tmp/storage") : Rails.root.join("storage")
  end

  def image_dir
    storage_root.join("generated_images")
  end

  def pdf_dir
    storage_root.join("generated_pdfs")
  end

  def headline
    base = @manuscript.catch_copy.presence ||
      "#{@manuscript.service_name}のことなら私たちにお任せください！"

    return base if @edit_instruction.blank?

    if @edit_instruction.include?("緊急") || @edit_instruction.include?("急")
      "急な#{@manuscript.service_name}のお困りごと、今すぐご相談ください！"
    elsif @edit_instruction.include?("キャッチコピー")
      "#{@manuscript.target}の課題を、#{@manuscript.service_name}で解決します"
    else
      base
    end
  end

  def benefit_points
    parsed = @manuscript.strengths.to_s.split(/[、,\n]/).map(&:strip).reject(&:blank?)
    parsed = ["迅速対応", "安心のサポート", "わかりやすい料金", "豊富な実績"] if parsed.empty?
    parsed.first(4)
  end

  def concerns
    [
      "#{@manuscript.service_name}の相談先を探している",
      "信頼できる業者に依頼したい",
      @manuscript.urgency_reason.presence || "早めに問い合わせたい"
    ].first(3)
  end

  def svg_markup
    title_lines = wrap(headline, 13)
    body_lines = wrap_text_for_svg(generated_body, 28)
    body_y_start = 318
    body_font_size = 16
    body_line_height = 28
    max_body_lines = 14
    body_lines = body_lines.first(max_body_lines)

    # Calculate where contact section starts based on body length
    contact_y = body_y_start + (body_lines.length * body_line_height) + 40
    contact_y = 748 if contact_y < 748 # minimum position

    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="794" height="1123" viewBox="0 0 794 1123">
        <rect width="794" height="1123" fill="#ffffff"/>
        <rect x="36" y="34" width="722" height="1055" fill="#ffffff" stroke="#111111" stroke-width="2"/>
        #{text_block(title_lines, 397, 92, 34, 42, "middle", 900)}
        <text x="397" y="210" text-anchor="middle" font-family="sans-serif" font-size="24" font-weight="900">#{h(@manuscript.service_name)}</text>
        <rect x="76" y="242" width="642" height="42" rx="5" fill="#111111"/>
        <text x="397" y="271" text-anchor="middle" font-family="sans-serif" font-size="20" font-weight="900" fill="#ffffff">#{h(@manuscript.target)}向け #{h(@manuscript.purpose)}のご案内</text>

        <rect x="70" y="#{body_y_start}" width="654" height="#{body_lines.length * body_line_height + 24}" fill="#ffffff" stroke="#111111" stroke-width="2"/>
        #{text_block(body_lines, 92, body_y_start + body_font_size + 10, body_font_size, body_line_height, "start", 600)}

        <rect x="70" y="#{contact_y}" width="654" height="60" rx="6" fill="#111111"/>
        <text x="397" y="#{contact_y + 38}" text-anchor="middle" font-family="sans-serif" font-size="24" font-weight="900" fill="#ffffff">ご相談・お問い合わせはお気軽にどうぞ！</text>

        <rect x="70" y="#{contact_y + 80}" width="654" height="96" fill="#ffffff" stroke="#111111" stroke-width="2"/>
        <circle cx="124" cy="#{contact_y + 128}" r="30" fill="#111111"/>
        <text x="124" y="#{contact_y + 139}" text-anchor="middle" font-family="sans-serif" font-size="34" font-weight="900" fill="#ffffff">☎</text>
        <text x="178" y="#{contact_y + 137}" font-family="sans-serif" font-size="40" font-weight="900">#{h(@manuscript.phone_number.presence || "03-XXXX-XXXX")}</text>
        <text x="178" y="#{contact_y + 165}" font-family="sans-serif" font-size="15" font-weight="800">受付時間 #{h(@manuscript.reception_hours.presence || "平日 9:00〜18:00")}</text>

        <rect x="70" y="#{contact_y + 198}" width="654" height="70" fill="#ffffff" stroke="#111111" stroke-width="2"/>
        <text x="92" y="#{contact_y + 242}" font-family="sans-serif" font-size="18" font-weight="900">FAX</text>
        <text x="140" y="#{contact_y + 242}" font-family="sans-serif" font-size="21" font-weight="900">#{h(@manuscript.fax_number.presence || "03-XXXX-XXXX")}</text>
        <text x="410" y="#{contact_y + 242}" font-family="sans-serif" font-size="18" font-weight="900">WEB</text>
        <text x="468" y="#{contact_y + 242}" font-family="sans-serif" font-size="18" font-weight="900">#{h(@manuscript.website_url.presence || "https://example.jp")}</text>

        <rect x="70" y="1038" width="654" height="36" fill="#f3f3f3" stroke="#111111" stroke-width="1"/>
        <text x="92" y="1063" font-family="sans-serif" font-size="16" font-weight="900">#{h(@manuscript.display_company_name)}</text>
        <text x="432" y="1063" font-family="sans-serif" font-size="14" font-weight="700">#{h(@manuscript.target_region.presence || "対応エリアはご相談ください")}</text>
      </svg>
    SVG
  end

  def benefit_boxes
    benefit_points.each_with_index.map do |point, index|
      x = 70 + (index * 166)
      <<~SVG
        <rect x="#{x}" y="548" width="146" height="156" rx="7" fill="#ffffff" stroke="#111111" stroke-width="2"/>
        <circle cx="#{x + 73}" cy="598" r="26" fill="#111111"/>
        <text x="#{x + 73}" y="610" text-anchor="middle" font-family="sans-serif" font-size="31" font-weight="900" fill="#ffffff">#{index + 1}</text>
        #{text_block(wrap(point, 8).first(3), x + 73, 652, 15, 21, "middle", 900)}
      SVG
    end.join
  end

  def check_lines(items, x, y)
    items.each_with_index.map do |item, index|
      row_y = y + (index * 34)
      <<~SVG
        <rect x="#{x}" y="#{row_y - 18}" width="18" height="18" fill="#ffffff" stroke="#111111" stroke-width="2"/>
        <path d="M#{x + 4} #{row_y - 9} L#{x + 8} #{row_y - 4} L#{x + 16} #{row_y - 16}" fill="none" stroke="#111111" stroke-width="2"/>
        <text x="#{x + 30}" y="#{row_y}" font-family="sans-serif" font-size="15" font-weight="800">#{h(shorten(item, 17))}</text>
      SVG
    end.join
  end

  def text_block(lines, x, y, font_size, line_height, anchor, weight)
    lines.each_with_index.map do |line, index|
      <<~SVG
        <text x="#{x}" y="#{y + (index * line_height)}" text-anchor="#{anchor}" font-family="sans-serif" font-size="#{font_size}" font-weight="#{weight}">#{h(line)}</text>
      SVG
    end.join
  end

  def wrap(text, width)
    text.to_s.scan(/.{1,#{width}}/m).first(6)
  end

  def wrap_text_for_svg(text, width)
    lines = []
    text.to_s.split(/\n/).each do |paragraph|
      paragraph = paragraph.strip
      next if paragraph.empty?
      lines.concat(paragraph.scan(/.{1,#{width}}/m))
    end
    lines
  end

  def shorten(text, width)
    value = text.to_s
    value.length > width ? "#{value.first(width)}..." : value
  end

  def h(value)
    ERB::Util.html_escape(value.to_s)
  end
end
