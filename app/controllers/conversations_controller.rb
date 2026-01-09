class ConversationsController < ApplicationController

  before_action :set_conversation, only: [:show, :destroy]

  def index
    @current_user = current_user
    @conversations = @current_user.conversations
    .includes(:users, :conversation_memberships, messages: :user)
    .order(updated_at: :desc)
    .page(params[:page])
    .per(20)

    @online_users = User.online.where.not(id: current_user.id)
  
    # Set the conversation if an ID is provided
    if params[:id].present?
      @conversation = @conversations.find(params[:id])
      @messages = @conversation.messages.includes(:user).order(created_at: :asc)
    elsif @conversations.any?
      # Default to first conversation if none selected
      @conversation = @conversations.first
      @messages = @conversation.messages.includes(:user).order(created_at: :asc) if @conversation
    end
  end

  def show
    @messages = @conversation.messages
      .active
      .includes(:user, :attachments, :message_reads)
      .order(created_at: :asc)
      .page(params[:page])
      .per(50)

    @message = Message.new
    @conversation.mark_as_read_for(current_user)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

	def new
		@conversation = Conversation.new(conversation_type: :group_chat)
    @users = User.where.not(id: current_user.id).order(:username)
  end

	def create
    if params[:user_id].present?
      # Direct conversation
      other_user = User.find(params[:user_id])
      @conversation = Conversation.find_or_create_direct(current_user, other_user)
    else
      # Group conversation
      @conversation = Conversation.new(conversation_params)
      @conversation.conversation_type = :group_chat
      
      if @conversation.save
        # Add creator as admin
        @conversation.conversation_memberships.create!(
          user: current_user,
          is_admin: true
        )
        
        # Add other members
        user_ids = params[:user_ids].to_s.split(',').map(&:to_i)
        user_ids.each do |user_id|
          @conversation.conversation_memberships.create!(user_id: user_id)
        end
      end
    end

    if @conversation.persisted?
      redirect_to @conversation, notice: 'Conversation created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

	def destroy
    membership = @conversation.conversation_memberships.find_by(user: current_user)
    
    if membership&.destroy
      redirect_to conversations_path, notice: 'You left the conversation.'
    else
      redirect_to @conversation, alert: 'Unable to leave conversation.'
    end
  end

  def search
    searcher = ConversationSearcher.new(user: current_user, query: params[:q])
    @conversations = searcher.search

    render :index
  end

	private

  def set_conversation
    @conversation = current_user.conversations.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to conversations_path, alert: 'Conversation not found.'
  end

  def conversation_params
		params.require(:conversation).permit(:title, :conversation_type, user_ids: [])
	end
end
