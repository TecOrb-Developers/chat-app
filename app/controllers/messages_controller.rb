class MessagesController < ApplicationController
  before_action :set_conversation
  before_action :set_message, only: [:update, :destroy]

 def create
  @message = MessageCreator.new(
    conversation: @conversation,
    user: current_user,
    content: message_params[:content],
    attachments: process_attachments,
  ).call

  if @message&.persisted?
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          # Append the new message to the messages list
          turbo_stream.append("messages", 
            partial: "messages/message", 
            locals: { 
              message: @message,
              current_user: current_user
            }
          ),
          # Reset the form
          turbo_stream.replace("message-form",
            partial: "conversations/message_form",
            locals: {
              conversation: @conversation,
              message: Message.new
            }
          ),
          # # Scroll to bottom (optional)
          # turbo_stream.update("messages", 
          #   partial: "shared/scroll_to_bottom"
          # )
        ]
      end
      format.json { render json: { status: 'success', message: @message } }
    end
  else
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("message-form",
          partial: "conversations/message_form",
          locals: {
            conversation: @conversation,
            message: @message || Message.new,
            error: @message&.errors&.full_messages&.to_sentence || "Failed to send message"
          }
        )
      end
      format.json { render json: { status: 'error', message: 'Failed to send message' } }
    end
  end
end

  def update
    if @message.user == current_user
      if @message.update(content: message_params[:content], edited_at: Time.current)
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to @conversation }
        end
      else
        render :edit, status: :unprocessable_entity
      end
    else
      redirect_to @conversation, alert: 'You can only edit your own messages.'
    end
  end

  def destroy
    if @message.user == current_user || conversation_admin?
      @message.soft_delete!
      
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @conversation }
      end
    else
      redirect_to @conversation, alert: 'You cannot delete this message.'
    end
  end

	private

  def set_conversation
    @conversation = current_user.conversations.find(params[:conversation_id])
  end

  def set_message
    @message = @conversation.messages.find(params[:id])
  end

  def message_params
    params.require(:message).permit(:content, :conversation_id, attachments: [])
  end

  def find_parent_message
    return nil unless params[:message][:parent_message_id].present?
    @conversation.messages.find_by(id: params[:message][:parent_message_id])
  end

  def process_attachments
    return [] unless params[:message][:attachments].present?
    
    # This would handle file uploads via Active Storage or similar
    # For now, returning empty array
    []
  end

	def conversation_admin?
    @conversation.conversation_memberships
      .find_by(user: current_user)
      &.is_admin?
  end
end
