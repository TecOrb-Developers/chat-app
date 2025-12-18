# app/controllers/users/registrations_controller.rb
class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_account_update_params, only: [:update]

  protected

  def update_resource(resource, params)
    # Allows user to update their information without password
    if params[:password].blank? && params[:password_confirmation].blank?
      params.delete(:current_password)
      resource.update_without_password(params)
    else
      resource.update_with_password(params)
    end
  end

  def after_update_path_for(resource)
    # Redirect back to the same page after update
    stored_location_for(resource) || request.referer || root_path
  end

  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, 
      keys: [:username, :email, :password, :password_confirmation, :current_password])
  end
end