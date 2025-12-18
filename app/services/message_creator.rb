class MessageCreator
  def initialize(conversation:, user:, content:, attachments: [], parent_message: nil)
    @conversation = conversation
    @user = user
    @content = content
    @attachments = attachments
    @parent_message = parent_message
  end

  def call
    ApplicationRecord.transaction do
      message = create_message
      process_attachments(message) if @attachments.any?
      notify_users(message)
      message
    end
  rescue StandardError => e
    Rails.logger.error "Failed to create message: #{e.message}"
    nil
  end

  private
  
  def create_message
    @conversation.messages.create!(
      user: @user,
      content: @content,
      parent_message: @parent_message,
      message_type: determine_message_type
    )
  end

  def determine_message_type
    return :image if @attachments.any? { |a| a[:type].starts_with?('image/') }
    return :file if @attachments.any?
    :text
  end

  def process_attachments(message)
    @attachments.each do |attachment_data|
      message.attachments.create!(
        file_name: attachment_data[:name],
        file_type: attachment_data[:type],
        file_size: attachment_data[:size],
        url: attachment_data[:url],
        metadata: attachment_data[:metadata] || {}
      )
    end
  end

  def notify_users(message)
    NotificationJob.perform_later(message.id)
  end
end