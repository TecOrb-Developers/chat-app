class PresenceChannel < ApplicationCable::Channel
  def subscribed
    stream_from "presence_#{current_user.id}"
    broadcast_online_status(true)
  end

  def unsubscribed
    broadcast_online_status(false)
  end

  def appear
    current_user.update_last_seen!
    broadcast_online_status(true)
  end

  def away
    broadcast_online_status(false)
  end

  private

  def broadcast_online_status(online)
    # Broadcast to all user's conversations
    current_user.conversations.each do |conversation|
      ActionCable.server.broadcast(
        "conversation_#{conversation.id}_presence",
        {
          user_id: current_user.id,
          username: current_user.display_name,
          online: online,
          last_seen_at: current_user.last_seen_at
        }
      )
    end
  end
end
