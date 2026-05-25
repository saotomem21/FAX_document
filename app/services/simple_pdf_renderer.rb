class SimplePdfRenderer
  def self.render(manuscript, version_number:)
    new(manuscript, version_number).render
  end

  def initialize(manuscript, version_number)
    @manuscript = manuscript
    @version_number = version_number
  end

  def render
    body = [
      "BT",
      "/F1 22 Tf",
      "72 760 Td",
      "(FAX Manuscript AI) Tj",
      "/F1 14 Tf",
      "0 -36 Td",
      "(Title: #{safe(@manuscript.title)}) Tj",
      "0 -24 Td",
      "(Service: #{safe(@manuscript.service_name)}) Tj",
      "0 -24 Td",
      "(Target: #{safe(@manuscript.target)}) Tj",
      "0 -24 Td",
      "(Purpose: #{safe(@manuscript.purpose)}) Tj",
      "0 -24 Td",
      "(Contact: #{safe(@manuscript.contact_methods)}) Tj",
      "0 -24 Td",
      "(Version: #{@version_number}) Tj",
      "ET"
    ].join("\n")

    objects = []
    objects << "<< /Type /Catalog /Pages 2 0 R >>"
    objects << "<< /Type /Pages /Kids [3 0 R] /Count 1 >>"
    objects << "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>"
    objects << "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
    objects << "<< /Length #{body.bytesize} >>\nstream\n#{body}\nendstream"

    pdf = +"%PDF-1.4\n"
    offsets = [0]
    objects.each_with_index do |object, index|
      offsets << pdf.bytesize
      pdf << "#{index + 1} 0 obj\n#{object}\nendobj\n"
    end

    xref_offset = pdf.bytesize
    pdf << "xref\n0 #{objects.length + 1}\n"
    pdf << "0000000000 65535 f \n"
    offsets.drop(1).each { |offset| pdf << format("%010d 00000 n \n", offset) }
    pdf << "trailer\n<< /Size #{objects.length + 1} /Root 1 0 R >>\n"
    pdf << "startxref\n#{xref_offset}\n%%EOF\n"
    pdf
  end

  private

  def safe(value)
    value.to_s.encode("US-ASCII", invalid: :replace, undef: :replace, replace: "?").gsub(/[()\\]/) { |char| "\\#{char}" }
  end
end
