class ApplicationController < ActionController::API
  before_action :authenticate_user!

  private

  def authenticate_user!
    user = user_from_bearer_token
    if user
      @current_user = user
    else
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  def authenticate_user_from_token_if_present
    @current_user = user_from_bearer_token
  end

  def current_user
    @current_user
  end

  def user_from_bearer_token
    header = request.headers["Authorization"]
    token = header&.split(" ")&.last
    return nil if token.blank?

    begin
      decoded = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: "HS256")
      User.find(decoded[0]["user_id"])
    rescue JWT::DecodeError, ActiveRecord::RecordNotFound
      nil
    end
  end

  def require_attendee!
    return if current_user.attendee?

    render json: { error: "Forbidden" }, status: :forbidden
  end
end
