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
      #send_mobile_notification(membership.user, message) if mobile_user?(membership.user)
    end
	end

  private

  def send_web_notification(user, message)
    NotificationChannel.broadcast_to(
      user,
      {
        title: message.conversation.display_name(for_user: user),
        body: truncate_content(message.content),
        conversation_id: message.conversation.id,
        message_id: message.id,
        sender_avatar: message.user.avatar
      }
    )
  end

	def truncate_content(content, length = 100)
    content.length > length ? "#{content[0...length]}..." : content
  end
end