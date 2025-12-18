module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
      UserPresenceJob.perform_later(current_user.id) if current_user
    end

    def disconnect
      update_user_presence if current_user
    end

    private

    def find_verified_user
      if verified_user = env['warden']&.user
        verified_user
      else
        reject_unauthorized_connection
      end
    end

    def update_user_presence
      current_user.update_last_seen!
    end
  end
end
