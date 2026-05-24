class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user, :current_company, :logged_in?

  private

  def current_user
    @current_user ||= User.includes(:company).find_by(id: session[:user_id]) if session[:user_id].present?
  end

  def current_company
    current_user&.company
  end

  def logged_in?
    current_user.present?
  end

  def require_login
    return if logged_in?

    redirect_to login_path, alert: "ログインしてください。"
  end
end
