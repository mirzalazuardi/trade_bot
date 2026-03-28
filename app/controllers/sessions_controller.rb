class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    user = User.find_by(email_address: params[:email_address])

    if user&.locked?
      redirect_to new_session_path, alert: "Account locked. Try again later."
      return
    end

    if authenticated_user = User.authenticate_by(params.permit(:email_address, :password))
      authenticated_user.reset_failed_login!
      start_new_session_for authenticated_user, remember_me: params[:remember_me] == "1"
      redirect_to after_authentication_url
    else
      user&.register_failed_login!
      redirect_to new_session_path, alert: "Invalid email or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
