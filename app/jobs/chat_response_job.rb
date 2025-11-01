class ChatResponseJob < ApplicationJob
  def perform(chat_id, content)
    chat = Chat.find(chat_id)

    # Use RAG to generate answer with relevant context from documents
    result = Rag::AnswerGenerator.generate(content)

    # Create the user message
    user_message = chat.messages.create!(
      role: 'user',
      content: content
    )

    # Create the assistant message with the RAG-generated answer
    assistant_message = chat.messages.create!(
      role: 'assistant',
      content: result[:answer]
    )

    # Broadcast the messages for Turbo Streams (HTML interface)
    user_message.broadcast_append_to("chat_#{chat.id}", target: "messages")
    assistant_message.broadcast_append_to("chat_#{chat.id}", target: "messages")
  end
end