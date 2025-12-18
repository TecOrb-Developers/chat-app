class ConversationChannel < ApplicationCable::Channel
  def subscribed
    conversation = Conversation.find(params[:id])
    # Verify user is member
    return reject unless conversation.users.include?(current_user)
    
    stream_for conversation
    
    # Mark messages as read when user subscribes
    mark_messages_as_read(conversation)
    
    # Broadcast user joined
    broadcast_presence(:joined)
  end

  def unsubscribed
    conversation = Conversation.find_by(id: params[:id])
    
    if conversation
      # Remove typing indicator
      conversation.remove_typing_user(current_user)
      broadcast_typing_update(conversation)
      
      # Broadcast user left
      broadcast_presence(:left)
    end
  end

  # def receive(data)
  #   # Handle typing indicators, read receipts, etc.
  #   ConversationChannel.broadcast_to(
  #     Conversation.find(params[:id]),
  #     data
  #   )
  # end

  def speak(data)
    conversation = Conversation.find(params[:id])
    
    message = MessageCreator.new(
      conversation: conversation,
      user: current_user,
      content: data['message'],
      attachments: data['attachments'] || []
    ).call

    if message
      # Stop typing indicator
      stop_typing
    else
      # Send error back to client
      transmit({
        error: 'Failed to send message',
        timestamp: Time.current.iso8601
      })
    end
  end

  def typing
    conversation = Conversation.find(params[:id])
    conversation.add_typing_user(current_user)
    broadcast_typing_update(conversation)
  end

  def stop_typing
    conversation = Conversation.find(params[:id])
    conversation.remove_typing_user(current_user)
    broadcast_typing_update(conversation)
  end

  def mark_read(data)
    message = Message.find_by(id: data['message_id'])
    return unless message

    message.mark_as_read_by(current_user)
    
    # Update unread count
    membership = current_user.conversation_memberships.find_by(conversation: message.conversation)
    membership&.update(unread_count: 0, last_read_at: Time.current)
  end

  private

  def mark_messages_as_read(conversation)
    unread_messages = conversation.messages
      .where.not(user: current_user)
      .where.missing(:message_reads)
      .or(conversation.messages.where.not(message_reads: { user_id: current_user.id }))

    unread_messages.find_each do |message|
      message.mark_as_read_by(current_user)
    end

    # Reset unread count
    membership = current_user.conversation_memberships.find_by(conversation: conversation)
    membership&.update(unread_count: 0, last_read_at: Time.current)
  end

  def broadcast_presence(status)
    conversation = Conversation.find_by(id: params[:id])
    return unless conversation

    ConversationChannel.broadcast_to(
      conversation,
      {
        type: 'presence',
        status: status,
        user: {
          id: current_user.id,
          username: current_user.display_name,
          avatar: current_user.avatar
        },
        timestamp: Time.current.iso8601
      }
    )
  end

  def broadcast_typing_update(conversation)
    typing_users = conversation.typing_users(exclude_user: current_user)
    puts typing_users.inspect
    ConversationChannel.broadcast_to(
      conversation,
      {
        type: 'typing',
        users: typing_users.map { |u| { id: u.id, username: u.display_name } },
        timestamp: Time.current.iso8601
      }
    )
  end
end
