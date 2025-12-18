class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :user

  validates :content, presence: true, length: { maximum: 10000 }
  belongs_to :parent_message, class_name: 'Message', optional: true
  
  has_many :replies, class_name: 'Message', foreign_key: :parent_message_id, dependent: :nullify
  has_many :message_reads, dependent: :destroy
  has_many :attachments, as: :attachable, dependent: :destroy

  enum :message_type, { text: 0, system: 1, file: 2, image: 3 }
  validates :content, presence: true, unless: :has_attachments?
  validates :message_type, presence: true

  scope :active, -> { where(deleted_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_users, -> { includes(:user) }
  scope :unread_for, ->(user) { 
    left_joins(:message_reads)
      .where(message_reads: { user_id: nil })
      .or(where.not(message_reads: { user_id: user.id }))
  }

  after_create_commit :broadcast_message, :update_conversation_timestamp, 
                      :increment_unread_counts, :clear_typing_indicator
  after_update_commit :broadcast_message_update
  after_destroy_commit :broadcast_message_removal

  def read_by?(user)
    message_reads.exists?(user: user)
  end

  def mark_as_read_by(user)
    return if user == self.user # Don't mark own messages as read
    
    message_reads.find_or_create_by(user: user) do |mr|
      mr.read_at = Time.current
    end
  end

  def read_by_users
    User.joins(:message_reads).where(message_reads: { message_id: id })
  end

  def soft_delete!
    update(
      deleted_at: Time.current,
      content: '[Message deleted]',
      metadata: metadata.merge(deleted: true)
    )
  end

  def edited?
    edited_at.present?
  end

  def deleted?
    deleted_at.present?
  end

  def display_content
    deleted? ? "[Message deleted]" : content
  end

  private

  def has_attachments?
    attachments.any?
  end

  def broadcast_message
    conversation.users.find_each do |recipient|
      broadcast_append_to(
        [recipient, conversation],
        target: "messages",
        partial: "messages/message",
        locals: { message: self, current_user: recipient }
      )
    end

    # Update each user’s conversation list row
    conversation.users.find_each do |recipient|
      broadcast_replace_to(
        [recipient, "conversations"],
        target: "conversation_#{conversation.id}",
        partial: "conversations/conversation_item",
        locals: { conversation: conversation, user: recipient }
      )
    end
  end

  def broadcast_message_update
    broadcast_replace_to(
      conversation,
      target: "message_#{id}",
      partial: "messages/message",
      locals: { message: self }
    )
  end

  def broadcast_message_removal
    broadcast_remove_to conversation, target: "message_#{id}"
  end

  def update_conversation_timestamp
    conversation.update_column(:last_message_at, created_at)
  end

  def increment_unread_counts
    conversation.increment_unread_for_all_except(user)
  end

  def broadcast_message_update
    broadcast_replace_to(
      conversation,
      target: "message_#{id}",
      partial: "messages/message",
      locals: { message: self }
    )
  end

  def broadcast_message_removal
    broadcast_remove_to conversation, target: "message_#{id}"
  end

  def update_conversation_timestamp
    conversation.update_column(:last_message_at, created_at)
  end

  def increment_unread_counts
    conversation.increment_unread_for_all_except(user)
  end

  def clear_typing_indicator
    conversation.remove_typing_user(user) if conversation.respond_to?(:remove_typing_user)
  end
end
