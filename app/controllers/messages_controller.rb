class MessagesController < ApplicationController
  before_action :set_chat

  def create
    unless content.present?
      return respond_to do |format|
        format.json { render json: { error: "Content cannot be blank" }, status: :unprocessable_content }
        format.html { redirect_to @chat, alert: "Content cannot be blank" }
      end
    end

    ChatResponseJob.perform_later(@chat.id, content)

    respond_to do |format|
      format.json { render json: { message: "Message queued for processing" }, status: :accepted }
      format.turbo_stream
      format.html { redirect_to @chat }
    end
  end

  private

  def set_chat
    @chat = Chat.find(params[:chat_id])
  end

  def content
    params[:message][:content]
  end
end