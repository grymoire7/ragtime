class ChatResponseJob < ApplicationJob
  def perform(chat_id, content, options = {})
    chat = Chat.find(chat_id)

    # Use RAG to generate answer with relevant context from documents
    # Pass through any filtering options (e.g., created_after for date filtering)
    result = Rag::AnswerGenerator.generate(content, options)

    # Create the user message
    user_message = chat.messages.create!(
      role: 'user',
      content: content
    )

    # Create the assistant message with the RAG-generated answer and citations
    # Include empty_context if present to help frontend display appropriate messages
    metadata = { citations: result[:citations] }
    metadata[:empty_context] = result[:empty_context] if result[:empty_context].present?

    assistant_message = chat.messages.create!(
      role: 'assistant',
      content: result[:answer],
      metadata: metadata
    )

    # Broadcast the messages for Turbo Streams (HTML interface)
    user_message.broadcast_append_to("chat_#{chat.id}", target: "messages")
    assistant_message.broadcast_append_to("chat_#{chat.id}", target: "messages")
  end
end