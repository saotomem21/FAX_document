require "fileutils"

module Pdf
  class FaxManuscriptExporter
    def initialize(manuscript)
      @manuscript = manuscript
    end

    def export!(version_number:)
      begin
        pdf_dir = storage_root.join("generated_pdfs")
        FileUtils.mkdir_p(pdf_dir)

        pdf_path = pdf_dir.join("manuscript_#{@manuscript.id}_v#{version_number}.pdf")

        # Compile PDF stream
        pdf_content = SimplePdfRenderer.render(@manuscript, version_number: version_number)
        File.binwrite(pdf_path, pdf_content)

        pdf_path_relative = pdf_path.relative_path_from(Rails.root).to_s

        @manuscript.update!(
          generated_pdf_path: pdf_path_relative
        )

        pdf_path_relative
      rescue => e
        Rails.logger.error "PDF Export failed: #{e.message}"
        raise e
      end
    end

    private

    def storage_root
      Rails.env.test? ? Rails.root.join("tmp/storage") : Rails.root.join("storage")
    end
  end
end