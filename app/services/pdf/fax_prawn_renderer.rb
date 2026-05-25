module Pdf
  class FaxPrawnRenderer
    class PrawnNotAvailableError < StandardError; end

    PRAWN_AVAILABLE = begin
      require "prawn"
      true
    rescue LoadError
      false
    end

    # Japanese font paths (searched in order, first available wins)
    JAPANESE_FONT_PATHS = [
      "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",  # Docker (fonts-noto-cjk)
      "/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf",       # Docker (fonts-ipafont-gothic)
      "/System/Library/Fonts/Hiragino Sans GB.ttc",              # macOS
      "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",  # alt Docker path
    ].freeze

    def initialize(manuscript, structure: nil)
      @manuscript = manuscript
      raw = structure || manuscript.generated_structure
      raw = JSON.parse(raw) if raw.is_a?(String)
      @s = migrate_old_structure(raw || {})
    end

    # Backward compatibility: convert old-style structure to new format
    def migrate_old_structure(s)
      return s if s["target_label"] || s["problem_points"] || s["solution_points"]
      # Old format: { headline, target_notice, points, body_text, contact_notice }
      return s unless s["points"] || s["contact_notice"]
      {
        "target_label" => s["target_notice"],
        "headline" => s["headline"],
        "subheadline" => nil,
        "problem_points" => [],
        "solution_points" => Array(s["points"]),
        "service_items" => [],
        "cta" => s["contact_notice"],
        "reply_form_fields" => ["会社名", "ご担当者名", "電話番号", "FAX番号", "ご相談内容"],
        "footer_note" => "FAX不要の方は、配信停止欄よりご連絡ください"
      }
    end

    def render
      raise PrawnNotAvailableError, "Prawn gem is not installed. Run `bundle install`." unless PRAWN_AVAILABLE

      doc = Prawn::Document.new(
        page_size: "A4",
        margin: [28, 28, 28, 28]
      )

      register_japanese_font(doc)

      draw_border(doc)
      y = doc.cursor - 8

      y = draw_target_label(doc, y)
      y = draw_headline(doc, y)
      y = draw_divider(doc, y)
      y = draw_problems_solutions(doc, y)
      y = draw_service_items(doc, y)
      y = draw_strengths(doc, y)
      y = draw_cta(doc, y)
      y = draw_reply_form(doc, y)
      y = draw_qr_placeholder(doc, y)
      y = draw_company_info(doc, y)
      draw_footer(doc, y)

      doc.render
    end

    def self.render(manuscript, structure: nil)
      new(manuscript, structure: structure).render
    end

    def s_val(key)
      @s[key].presence
    end

    def safe(text)
      text.to_s.strip
    end

    def register_japanese_font(doc)
      regular = JAPANESE_FONT_PATHS.find { |p| File.exist?(p) }
      bold_path = regular.to_s.sub("Regular", "Bold") if regular
      bold = File.exist?(bold_path.to_s) ? bold_path : regular

      if regular
        doc.font_families.update(
          "JP" => {
            normal: regular,
            bold: bold,
            italic: regular,
            bold_italic: bold
          }
        )
        doc.font("JP")
        Rails.logger.info "FaxPrawnRenderer: Using Japanese font: #{regular}"
      else
        Rails.logger.warn "FaxPrawnRenderer: No Japanese font found, CJK text may not render"
      end
    end

    def draw_border(doc)
      doc.stroke_color "000000"
      doc.line_width 2
      doc.stroke_rectangle [0, doc.bounds.height], doc.bounds.width, doc.bounds.height
      doc.line_width 1
    end

    def draw_target_label(doc, y)
      target = s_val("target_label")
      return y unless target.present?

      doc.fill_color "000000"
      doc.font_size 14
      doc.text_box target,
        at: [0, y],
        width: doc.bounds.width,
        align: :left,
        style: :bold
      y - 30
    end

    def draw_headline(doc, y)
      headline = s_val("headline") || @manuscript.service_name
      sub = s_val("subheadline")

      # Headline box
      doc.fill_color "000000"
      doc.fill_rectangle [0, y], doc.bounds.width, 52
      doc.fill_color "FFFFFF"
      doc.font_size 22
      doc.text_box headline,
        at: [10, y - 8],
        width: doc.bounds.width - 20,
        align: :center,
        style: :bold
      doc.fill_color "000000"
      y -= 60

      if sub.present?
        doc.font_size 13
        doc.text_box sub,
          at: [0, y],
          width: doc.bounds.width,
          align: :center
        y -= 28
      end

      y
    end

    def draw_divider(doc, y)
      doc.stroke_color "000000"
      doc.line_width 2
      doc.horizontal_line 40, doc.bounds.width - 40, at: y
      doc.line_width 1
      y - 16
    end

    def draw_problems_solutions(doc, y)
      problems = Array(@s["problem_points"]).reject(&:blank?)
      solutions = Array(@s["solution_points"]).reject(&:blank?)

      return y if problems.empty? && solutions.empty?

      half_w = (doc.bounds.width - 20) / 2

      if problems.any?
        draw_section_box(doc, "▼ 課題", problems, 0, y, half_w)
      end

      if solutions.any?
        draw_section_box(doc, "▼ 解決策", solutions, half_w + 20, y, half_w)
      end

      line_count = [problems.size, solutions.size].max
      y - (line_count * 24) - 50
    end

    def draw_section_box(doc, title, items, x, y, width)
      box_h = (items.size * 24) + 44

      doc.stroke_color "333333"
      doc.line_width 1.5
      doc.stroke_rectangle [x, y], width, box_h

      doc.fill_color "000000"
      doc.font_size 14
      doc.text_box title,
        at: [x + 10, y - 8],
        width: width - 20,
        style: :bold

      items.each_with_index do |item, i|
        doc.font_size 12
        doc.text_box "・#{safe(item)}",
          at: [x + 14, y - 34 - (i * 24)],
          width: width - 28
      end
    end

    def draw_service_items(doc, y)
      items = Array(@s["service_items"]).reject(&:blank?)
      return y unless items.any?

      y -= 10

      doc.fill_color "000000"
      doc.font_size 14
      doc.text_box "【サービス内容】", at: [0, y], width: doc.bounds.width, style: :bold
      y -= 24

      items.each do |item|
        doc.font_size 13
        doc.text_box "・#{safe(item)}", at: [20, y], width: doc.bounds.width - 40
        y -= 22
      end

      y - 6
    end

    def draw_strengths(doc, y)
      items = Array(@s["strengths"]).reject(&:blank?)
      return y unless items.any?

      y -= 10

      doc.fill_color "000000"
      doc.font_size 14
      doc.text_box "【選ばれる理由・強み】", at: [0, y], width: doc.bounds.width, style: :bold
      y -= 24

      items.each do |item|
        doc.font_size 13
        doc.text_box "✓ #{safe(item)}", at: [20, y], width: doc.bounds.width - 40
        y -= 22
      end

      y - 6
    end

    def draw_cta(doc, y)
      cta = s_val("cta") || "お気軽にお問い合わせください"
      y -= 14

      # CTA background bar
      doc.fill_color "000000"
      doc.fill_rectangle [0, y], doc.bounds.width, 44
      doc.fill_color "FFFFFF"
      doc.font_size 18
      doc.text_box cta,
        at: [10, y - 8],
        width: doc.bounds.width - 20,
        align: :center,
        style: :bold
      doc.fill_color "000000"

      y - 56
    end

    def draw_reply_form(doc, y)
      fields = Array(@s["reply_form_fields"]).reject(&:blank?)
      return y unless fields.any?

      doc.font_size 13
      doc.text_box "【FAX返信フォーム】", at: [0, y], width: doc.bounds.width, style: :bold
      y -= 26

      doc.stroke_color "555555"
      doc.line_width 1

      fields.each do |field|
        doc.stroke_rectangle [0, y], doc.bounds.width, 22
        doc.font_size 11
        doc.text_box safe(field),
          at: [8, y - 4],
          width: doc.bounds.width - 60,
          style: :bold
        y -= 24
      end

      doc.line_width 1
      y - 6
    end

    def draw_qr_placeholder(doc, y)
      y -= 6

      # Right-aligned QR placeholder box
      qr_size = 72
      qr_x = doc.bounds.width - qr_size - 10

      doc.stroke_color "555555"
      doc.line_width 1.5
      doc.dash(4, space: 4)
      doc.stroke_rectangle [qr_x, y], qr_size, qr_size
      doc.undash

      doc.fill_color "666666"
      doc.font_size 8
      doc.text_box "QRコード\n差し替え枠",
        at: [qr_x + 4, y - 28],
        width: qr_size - 8,
        align: :center,
        valign: :center

      doc.fill_color "000000"
      y - qr_size - 4
    end

    def draw_company_info(doc, y)
      y -= 8

      company = @manuscript.display_company_name.presence || "株式会社サンプル"
      phone = @manuscript.phone_number.presence || "03-1234-5678"
      fax = @manuscript.fax_number.presence || "03-1234-5679"
      email_val = @manuscript.email.presence || "info@example.jp"
      url = @manuscript.website_url.presence || "https://example.jp"
      address = @manuscript.address.presence || "〒100-0001 東京都○○区○○ 1-2-3"
      hours = @manuscript.reception_hours.presence || "平日 9:00〜18:00"
      region = @manuscript.target_region.presence || "東京都・神奈川県・埼玉県"
      dept = @manuscript.department.presence || "営業部"

      doc.stroke_color "555555"
      doc.line_width 1
      doc.stroke_rectangle [0, y], doc.bounds.width, 102

      doc.font_size 12
      texts = [
        ["会社名：#{company}", 0],
        ["TEL：#{phone}　FAX：#{fax}", 0],
        ["MAIL：#{email_val}　URL：#{url}", 0],
        ["住所：#{address}", 0],
        ["受付：#{hours}　対応エリア：#{region}", 0],
        ["担当：#{dept}", 0]
      ]

      texts.each_with_index do |(text, _), i|
        doc.text_box text,
          at: [10, y - 10 - (i * 16)],
          width: doc.bounds.width - 20,
          size: 10
      end

      y - 112
    end

    def draw_footer(doc, y)
      note = s_val("footer_note") || "FAX不要の方は、配信停止欄よりご連絡ください"

      doc.fill_color "666666"
      doc.stroke_color "999999"
      doc.line_width 0.5
      doc.stroke_rectangle [0, y], doc.bounds.width, 22
      doc.font_size 9
      doc.text_box "【配信停止】#{safe(note)}",
        at: [8, y - 4],
        width: doc.bounds.width - 20
    end
  end
end