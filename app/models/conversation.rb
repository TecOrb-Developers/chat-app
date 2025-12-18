class Conversation < ApplicationRecord
  include ActionView::RecordIdentifier
  enum :conversation_type, { direct_message: 0, group_chat: 1, channel: 2 }
  has_many :conversation_memberships, dependent: :destroy
  has_many :users, through: :conversation_memberships
  has_many :messages, dependent: :destroy

  validates :title, presence: true, length: { maximum: 255 }

	validates :conversation_type, presence: true

  scope :recent, -> { order(last_message_at: :desc, updated_at: :desc) }
  scope :with_user, ->(user) { joins(:users).where(users: { id: user.id }) }

  after_create_commit -> { 
    broadcast_to_conversation
  }

  after_update_commit -> { 
    broadcast_to_conversation
  }

  def broadcast_to_conversation
    # Broadcast to each participant with their own context
    users.each do |user|
      broadcast_replace_later_to [user, "conversations"], 
        target: dom_id(self),
        partial: "conversations/conversation",
        locals: { conversation: self, user: user }
    end
  end

	def self.between_users(user1, user2)
    joins(:conversation_memberships)
      .where(conversation_type: :direct)
      .where(conversation_memberships: { user_id: [user1.id, user2.id] })
      .group('conversations.id')
      .having('COUNT(conversation_memberships.id) = 2')
      .first
  end

  def self.find_or_create_direct(user1, user2)
    conversation = between_users(user1, user2)
    return conversation if conversation

    transaction do
      conversation = create!(
        conversation_type: :direct,
        title: "#{user1.display_name}, #{user2.display_name}"
      )
      conversation.conversation_memberships.create!([
        { user: user1 },
        { user: user2 }
      ])
      conversation
    end
  end

	def display_name(for_user: nil)
    if direct_message? && for_user
      other_user = users.where.not(id: for_user.id).first
      other_user&.display_name || 'Unknown User'
    else
      title
    end
  end

  def display_avatar(for_user: nil)
    if direct_message? && for_user
      other_user = users.where.not(id: for_user.id).first
      other_user&.avatar
    else
      # For group chats, could show combined avatars or default
      "https://ui-avatars.com/api/?name=#{CGI.escape(title)}&background=random"
    end
  end

  def last_message
    messages.order(created_at: :desc).first
  end

	def mark_as_read_for(user)
    membership = conversation_memberships.find_by(user: user)
    return unless membership

    membership.update(
      last_read_at: Time.current,
      unread_count: 0
    )
  end

  def increment_unread_for_all_except(sender)
    conversation_memberships
      .where.not(user_id: sender.id)
      .update_all('unread_count = unread_count + 1')
  end

	def typing_users(exclude_user: nil)
    key = "conversation:#{id}:typing"
    typing_data = Rails.cache.read(key) || {}
    
    typing_data.reject! { |_, data| data[:expires_at] < Time.current }
    Rails.cache.write(key, typing_data, expires_in: 30.seconds)
    
    user_ids = typing_data.keys.map(&:to_i)
    user_ids -= [exclude_user.id] if exclude_user
    
    User.where(id: user_ids)
  end

  def add_typing_user(user)
    key = "conversation:#{id}:typing"
    typing_data = Rails.cache.read(key) || {}
    
    typing_data[user.id.to_s] = {
      user_id: user.id,
      username: user.display_name,
      expires_at: 10.seconds.from_now
    }
    
    Rails.cache.write(key, typing_data, expires_in: 30.seconds)
  end

	def remove_typing_user(user)
    key = "conversation:#{id}:typing"
    typing_data = Rails.cache.read(key) || {}
    typing_data.delete(user.id.to_s)
    Rails.cache.write(key, typing_data, expires_in: 30.seconds)
  end

  # Returns the count of unread messages for a specific user
  def unread_count(user)
    membership = conversation_memberships.find_by(user: user)
    return 0 unless membership
    
    messages.where('created_at > ?', membership.last_read_at).count
  end

  private

  def group_or_channel?
    group? || channel?
  end
end
