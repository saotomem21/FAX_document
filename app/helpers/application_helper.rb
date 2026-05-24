module ApplicationHelper
  def status_badge_class(status)
    {
      "generated" => "success",
      "reviewing" => "warning",
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
