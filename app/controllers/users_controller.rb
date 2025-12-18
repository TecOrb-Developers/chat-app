class UsersController < ApplicationController

  def index
    @users = User.where.not(id: current_user.id)
      .order(:username)
      .page(params[:page])
      .per(20)

    @users = @users.where('username LIKE ?', "%#{params[:q]}%") if params[:q].present?
  end

  def show
    @user = User.find(params[:id])
    @conversation = Conversation.between_users(current_user, @user)
  end
end
