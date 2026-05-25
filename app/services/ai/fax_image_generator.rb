require "erb"
require "fileutils"

module Ai
  class FaxImageGenerator
    def initialize(manuscript)
      @manuscript = manuscript
    end

    def generate!(version_number:)
      @manuscript.update!(status: "image_generating")

      begin
        # Ensure the directory exists
        image_dir = storage_root.join("generated_images")
        FileUtils.mkdir_p(image_dir)

        # Always generate SVG as reliable fallback
        svg_path = image_dir.join("manuscript_#{@manuscript.id}_v#{version_number}.svg")
        File.write(svg_path, svg_markup)
        svg_path_relative = svg_path.relative_path_from(Rails.root).to_s

        # Try DALL-E API generation (non-blocking — falls back to SVG on failure)
        generated_image_path = nil
        begin
          result = FaxImageApiGenerator.new(@manuscript).generate!(version_number: version_number)
          generated_image_path = result&.first # [relative_path, image_url]
        rescue => e
          Rails.logger.warn "[FaxImageGenerator] DALL-E generation failed, using SVG fallback: #{e.message}"
        end

        @manuscript.update!(
          generated_svg_path: svg_path_relative,
          generated_image_path: generated_image_path,
          image_generated_at: Time.current
        )

        svg_path_relative
      rescue => e
        Rails.logger.error "Image generation failed: #{e.message}"
        @manuscript.update!(status: "failed")
        raise e
      end
    end

    private

    def storage_root
      Rails.env.test? ? Rails.root.join("tmp/storage") : Rails.root.join("storage")
    end

    def svg_markup
      title_lines = wrap(headline, 13)
      body_lines = wrap_text_for_svg(@manuscript.generated_body || "", 28)
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

    def headline
      @manuscript.catch_copy.presence ||
        "#{@manuscript.service_name}のことなら私たちにお任せください！"
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

    def h(value)
      ERB::Util.html_escape(value.to_s)
    end
  end
end