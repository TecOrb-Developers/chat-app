class NotificationJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message

    conversation = message.conversation
    sender = message.user

    # Get all members except sender who have notifications enabled
    recipients = conversation.conversation_memberships
      .where.not(user_id: sender.id)
      .where(notifications_enabled: true)
      .includes(:user)

    recipients.each do |membership|
      # Here you would integrate with push notification service
      # For web: use Action Cable
      # For mobile: FCM/APNs via Hotwire Native bridge
      
      send_web_notification(membership.user, message)
      send_mobile_push_notification(membership.user, message)
    end

    # Also broadcast to ActionCable for real-time updates
    broadcast_message_to_conversation(message)
	end

  private

  def send_web_notification(user, message)
    NotificationChannel.broadcast_to(
      user,
      {
        type: 'push_notification',
        title: message.user.display_name,
        body: truncate_content(message.content),
        conversation_id: message.conversation.id,
        message_id: message.id,
        sender_id: message.user.id,
        sender_name: message.user.display_name,
        sender_avatar: message.user.avatar,
        timestamp: message.created_at.iso8601
      }
    )
  end

  def send_mobile_push_notification(user, message)
    # This will be handled by the Bridge Component on the frontend
    # We broadcast to a special channel that the bridge listens to
    ActionCable.server.broadcast(
      "push_notifications_#{user.id}",
      {
        type: 'mobile_push',
        title: message.user.display_name,
        body: truncate_content(message.content),
        conversation_id: message.conversation.id,
        message_id: message.id,
        sender_id: message.user.id,
        sender_name: message.user.display_name,
        timestamp: message.created_at.iso8601,
        badge: user.unread_messages_count
      }
    )
  end

  def broadcast_message_to_conversation(message)
    # Broadcast the actual message to the conversation channel
    ConversationChannel.broadcast_to(
      message.conversation,
      {
        type: 'message',
        id: message.id,
        content: message.content,
        sender_id: message.user.id,
        sender_name: message.user.display_name,
        sender_avatar: message.user.avatar,
        conversation_id: message.conversation.id,
        timestamp: message.created_at.iso8601,
        message_type: message.message_type
      }
    )
  end

	def truncate_content(content, length = 100)
    content.length > length ? "#{content[0...length]}..." : content
  end
end