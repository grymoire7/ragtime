class ChatsController < ApplicationController
  before_action :set_chat, only: [:show, :clear, :destroy]

  def index
    @chats = Chat.order(created_at: :desc)
  end

  def new
    @chat = Chat.new
    @selected_model = params[:model]
  end

  def create
    # Get model name from params or use default
    model_name = model || default_model

    # Find the Model record by model_id
    model_record = Model.find_by(model_id: model_name)
    unless model_record
      return render json: { error: "Model not found: #{model_name}" }, status: :unprocessable_content
    end

    @chat = Chat.create!(model: model_record)

    # If a prompt is provided, process it immediately
    if prompt.present?
      ChatResponseJob.perform_later(@chat.id, prompt)
    end

    respond_to do |format|
      format.html { redirect_to @chat, notice: 'Chat was successfully created.' }
      format.json { render json: @chat, status: :created }
    end
  end

  def show
    respond_to do |format|
      format.html do
        @message = @chat.messages.build
      end
      format.json do
        render json: {
          id: @chat.id,
          model: @chat.model&.name,
          created_at: @chat.created_at,
          messages: @chat.messages.where.not(id: nil).map do |msg|
            {
              id: msg.id,
              role: msg.role,
              content: msg.content,
              created_at: msg.created_at,
              metadata: msg.metadata || {}
            }
          end
        }
      end
    end
  end

  # DELETE /chats/:id/clear
  # Clear all messages from a chat (keeps the chat itself)
  def clear
    @chat.messages.destroy_all

    respond_to do |format|
      format.html { redirect_to @chat, notice: 'Conversation cleared.' }
      format.json { render json: { message: 'Conversation cleared' }, status: :ok }
    end
  end

  # DELETE /chats/:id
  # Delete the entire chat and all its messages
  def destroy
    @chat.destroy

    respond_to do |format|
      format.html { redirect_to root_path, notice: 'Chat deleted.' }
      format.json { head :no_content }
    end
  end

  private

  def set_chat
    @chat = Chat.find(params[:id])
  end

  def model
    params.dig(:chat, :model).presence
  end

  def prompt
    params.dig(:chat, :prompt)
  end

  def default_model
    chat_config = Rails.application.config.x.ruby_llm[Rails.env.to_sym][:chat]
    chat_config[:model]
  end
end