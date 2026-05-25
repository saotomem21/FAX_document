require "fileutils"

class ManuscriptGenerationService
  def initialize(manuscript, edit_instruction: nil)
    @manuscript = manuscript
    @edit_instruction = edit_instruction.to_s.strip.presence
  end

  # Generate PDF from the structure JSON using Prawn
  def generate_pdf!
    raise "generated_structure is blank" if @manuscript.generated_structure.blank?

    begin
      version_number = @manuscript.next_version_number

      # Create PDF storage directory
      pdf_dir = Rails.root.join("storage/generated_pdfs")
      FileUtils.mkdir_p(pdf_dir)

      # Render PDF with Prawn
      pdf_content = Pdf::FaxPrawnRenderer.render(@manuscript)
      pdf_path = pdf_dir.join("manuscript_#{@manuscript.id}_v#{version_number}.pdf")
      File.binwrite(pdf_path, pdf_content)
      pdf_path_relative = pdf_path.relative_path_from(Rails.root).to_s

      # Ensure generated_body is present
      body = @manuscript.generated_body.presence || fallback_generated_body
      @manuscript.update_columns(generated_body: body) if @manuscript.generated_body.blank?

      # Update manuscript
      @manuscript.update!(
        generated_pdf_path: pdf_path_relative,
        image_prompt_approved_at: Time.current,
        status: "generated"
      )

      # Save as version
      @manuscript.manuscript_versions.create!(
        version_number: version_number,
        edit_instruction: @edit_instruction,
        generated_body: body,
        image_prompt: @manuscript.image_prompt,
        generated_pdf_path: pdf_path_relative,
        generated_structure: @manuscript.generated_structure
      )

      @manuscript.company.increment!(:monthly_generation_count)
      @manuscript
    rescue Pdf::FaxPrawnRenderer::PrawnNotAvailableError => e
      Rails.logger.error "Prawn not available: #{e.message}"
      @manuscript.update!(status: "failed")
      raise e
    rescue => e
      Rails.logger.error "PDF generation failed: #{e.message}"
      @manuscript.update!(status: "failed")
      raise e
    end
  end

  # Legacy method — kept for backward compatibility, now delegates to generate_pdf!
  def generate_image_and_pdf!
    generate_pdf!
  end

  private

  def fallback_generated_body
    m = @manuscript
    parts = []
    parts << "#{m.service_name}のご案内"
    parts << ""
    parts << "対象: #{m.target}" if m.target.present?
    parts << "目的: #{m.purpose}" if m.purpose.present?
    parts << "概要: #{m.service_summary}" if m.service_summary.present?
    parts << "強み: #{m.strengths}" if m.strengths.present?
    parts << "お問い合わせ: #{m.form_contact_summary}" if m.form_contact_summary.present?
    parts.join("\n")
  end
end