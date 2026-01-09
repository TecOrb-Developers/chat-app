# app/channels/push_notification_channel.rb
class PushNotificationChannel < ApplicationCable::Channel
  def subscribed
    stream_from "push_notifications_#{current_user.id}"
  end

  def unsubscribed
    # Cleanup when user disconnects
  end

  def register_device_token(data)
    # Store device token for remote push notifications
    current_user.device_tokens.find_or_create_by(
      token: data['token'],
      platform: data['platform']
    ) do |device_token|
      device_token.active = true
      device_token.last_used_at = Time.current
    end
  end

  def update_app_state(data)
    # Track if app is in background/foreground
    # This helps determine when to send push notifications
    Rails.cache.write("user_#{current_user.id}_app_state", {
      is_background: data['is_background'],
      current_conversation_id: data['current_conversation_id'],
      updated_at: Time.current
    }, expires_in: 1.hour)
  end
end