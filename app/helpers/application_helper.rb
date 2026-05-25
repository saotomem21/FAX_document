module ApplicationHelper
  def presentation_mode?
    Ai::FaxPromptGenerator::PRESENTATION_MODE
  end

  def status_badge_class(status)
    {
      "generated" => "success",
      "prompt_generated" => "prompt",
      "prompt_generating" => "warning",
      "image_generating" => "warning",
      "failed" => "danger",
      "draft" => "neutral"
    }.fetch(status, "neutral")
  end

  def nav_active?(current, target)
    current.to_s == target.to_s ? "active" : nil
  end

  def lines_for(value)
    value.to_s.split(/[、,\n]/).map(&:strip).reject(&:blank?)
  end
end
