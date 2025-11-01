<template>
  <div class="chat-interface">
    <div class="chat-header">
      <h2>Ask Questions</h2>
      <button v-if="currentChat" @click="startNewChat" class="new-chat-btn">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor">
          <path d="M12 5v14M5 12h14"/>
        </svg>
        New Chat
      </button>
    </div>

    <div v-if="!currentChat" class="no-chat-state">
      <svg class="chat-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor">
        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path>
      </svg>
      <p>Start a conversation</p>
      <p class="subtext">Ask questions about your uploaded documents</p>
      <button @click="createChat" class="start-btn" :disabled="loading">
        Start Chat
      </button>
    </div>

    <div v-else class="chat-container">
      <div ref="messagesContainer" class="messages-container">
        <div v-if="messages.length === 0 && !loading" class="empty-messages">
          <p>No messages yet. Ask a question to get started!</p>
        </div>

        <div
          v-for="message in messages"
          :key="message.id"
          class="message"
          :class="`message-${message.role}`"
        >
          <div class="message-avatar">
            <span v-if="message.role === 'user'">You</span>
            <svg v-else viewBox="0 0 24 24" fill="none" stroke="currentColor">
              <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/>
            </svg>
          </div>
          <div class="message-content">
            <div class="message-text">{{ message.content }}</div>
            <div class="message-meta">{{ formatTime(message.created_at) }}</div>
          </div>
        </div>

        <div v-if="sending" class="message message-assistant loading-message">
          <div class="message-avatar">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor">
              <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/>
            </svg>
          </div>
          <div class="message-content">
            <div class="typing-indicator">
              <span></span>
              <span></span>
              <span></span>
            </div>
          </div>
        </div>
      </div>

      <form @submit.prevent="sendMessage" class="message-form">
        <div class="input-container">
          <textarea
            v-model="messageInput"
            placeholder="Ask a question about your documents..."
            rows="1"
            @keydown.enter.exact.prevent="sendMessage"
            @input="adjustTextareaHeight"
            ref="textarea"
            :disabled="sending"
          ></textarea>
          <button
            type="submit"
            :disabled="!messageInput.trim() || sending"
            class="send-btn"
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor">
              <line x1="22" y1="2" x2="11" y2="13"></line>
              <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
            </svg>
          </button>
        </div>
        <p class="input-hint">Press Enter to send, Shift+Enter for new line</p>
      </form>
    </div>

    <div v-if="error" class="error-message">
      {{ error }}
    </div>
  </div>
</template>

<script setup>
import { ref, nextTick, watch } from 'vue';
import { chatsAPI } from '../services/api';

const currentChat = ref(null);
const messages = ref([]);
const messageInput = ref('');
const sending = ref(false);
const loading = ref(false);
const error = ref('');
const messagesContainer = ref(null);
const textarea = ref(null);

async function createChat() {
  loading.value = true;
  error.value = '';

  try {
    const response = await chatsAPI.create();
    currentChat.value = response.data;
    messages.value = [];
  } catch (err) {
    error.value = 'Failed to create chat. Please try again.';
    console.error('Error creating chat:', err);
  } finally {
    loading.value = false;
  }
}

async function sendMessage() {
  if (!messageInput.value.trim() || sending.value) return;

  const content = messageInput.value.trim();
  messageInput.value = '';
  adjustTextareaHeight();

  // Add user message to UI immediately
  const userMessage = {
    id: `temp-${Date.now()}`,
    role: 'user',
    content: content,
    created_at: new Date().toISOString()
  };
  messages.value.push(userMessage);

  scrollToBottom();

  sending.value = true;
  error.value = '';

  try {
    // Send message to API
    await chatsAPI.sendMessage(currentChat.value.id, content);

    // Poll for updates since the response is generated asynchronously
    // Poll every 500ms for up to 30 seconds
    const maxAttempts = 60;
    let attempts = 0;
    const initialMessageCount = messages.value.length;

    const pollInterval = setInterval(async () => {
      attempts++;

      try {
        await loadChat(currentChat.value.id);

        // Check if we have an assistant response with content
        const hasAssistantResponse = messages.value.some(
          msg => msg.role === 'assistant' && msg.content && msg.content.trim().length > 0
        );

        // Stop polling if we got an assistant response with content or reached max attempts
        if (hasAssistantResponse || attempts >= maxAttempts) {
          clearInterval(pollInterval);
          sending.value = false;

          if (!hasAssistantResponse && attempts >= maxAttempts) {
            error.value = 'Response took too long. Please refresh to see the answer.';
          }
        }
      } catch (pollErr) {
        console.error('Error polling for updates:', pollErr);
        if (attempts >= maxAttempts) {
          clearInterval(pollInterval);
          sending.value = false;
          error.value = 'Failed to load response. Please try again.';
        }
      }
    }, 500);

  } catch (err) {
    error.value = 'Failed to send message. Please try again.';
    console.error('Error sending message:', err);
    // Remove the optimistically added message on error
    messages.value = messages.value.filter(m => m.id !== userMessage.id);
    sending.value = false;
  }
}

async function loadChat(chatId) {
  try {
    const response = await chatsAPI.get(chatId);
    console.log('Loaded chat data:', response.data);
    console.log('Messages:', response.data.messages);
    currentChat.value = response.data;
    messages.value = response.data.messages || [];
    console.log('Updated messages.value:', messages.value);
    await nextTick();
    scrollToBottom();
  } catch (err) {
    console.error('Error loading chat:', err);
  }
}

function startNewChat() {
  currentChat.value = null;
  messages.value = [];
  messageInput.value = '';
  error.value = '';
}

function scrollToBottom() {
  nextTick(() => {
    if (messagesContainer.value) {
      messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight;
    }
  });
}

function adjustTextareaHeight() {
  nextTick(() => {
    if (textarea.value) {
      textarea.value.style.height = 'auto';
      textarea.value.style.height = Math.min(textarea.value.scrollHeight, 200) + 'px';
    }
  });
}

function formatTime(dateString) {
  const date = new Date(dateString);
  return date.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
}

watch(messages, () => {
  scrollToBottom();
});
</script>

<style scoped>
.chat-interface {
  background-color: white;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  height: 600px;
}

.chat-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.5rem;
  border-bottom: 1px solid #e2e8f0;
  background-color: #f7fafc;
}

.chat-header h2 {
  margin: 0;
  font-size: 1.25rem;
  font-weight: 600;
  color: #2d3748;
}

.new-chat-btn {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  background-color: white;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  color: #4a5568;
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s;
}

.new-chat-btn:hover {
  background-color: #edf2f7;
  border-color: #cbd5e0;
}

.new-chat-btn svg {
  width: 16px;
  height: 16px;
  stroke-width: 2;
}

.no-chat-state {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 3rem;
  text-align: center;
  color: #718096;
}

.chat-icon {
  width: 64px;
  height: 64px;
  margin-bottom: 1rem;
  stroke-width: 1.5;
}

.no-chat-state p {
  margin: 0.5rem 0;
  font-size: 1.125rem;
}

.subtext {
  font-size: 0.875rem !important;
  color: #a0aec0;
}

.start-btn {
  margin-top: 1.5rem;
  padding: 0.75rem 2rem;
  background-color: #4299e1;
  color: white;
  border: none;
  border-radius: 6px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;
}

.start-btn:hover:not(:disabled) {
  background-color: #3182ce;
}

.start-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.chat-container {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.messages-container {
  flex: 1;
  overflow-y: auto;
  padding: 1.5rem;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.empty-messages {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #a0aec0;
  text-align: center;
}

.message {
  display: flex;
  gap: 0.75rem;
}

.message-avatar {
  flex-shrink: 0;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.75rem;
  font-weight: 600;
}

.message-user .message-avatar {
  background-color: #4299e1;
  color: white;
}

.message-assistant .message-avatar {
  background-color: #9f7aea;
  color: white;
}

.message-assistant .message-avatar svg {
  width: 18px;
  height: 18px;
  stroke-width: 2;
}

.message-content {
  flex: 1;
  min-width: 0;
}

.message-text {
  background-color: #f7fafc;
  padding: 0.75rem 1rem;
  border-radius: 8px;
  color: #2d3748;
  line-height: 1.5;
  white-space: pre-wrap;
  word-break: break-word;
}

.message-user .message-text {
  background-color: #4299e1;
  color: white;
}

.message-meta {
  margin-top: 0.25rem;
  font-size: 0.75rem;
  color: #a0aec0;
  padding-left: 0.25rem;
}

.typing-indicator {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.75rem 1rem;
  background-color: #f7fafc;
  border-radius: 8px;
  width: fit-content;
}

.typing-indicator span {
  width: 8px;
  height: 8px;
  background-color: #a0aec0;
  border-radius: 50%;
  animation: typing 1.4s infinite;
}

.typing-indicator span:nth-child(2) {
  animation-delay: 0.2s;
}

.typing-indicator span:nth-child(3) {
  animation-delay: 0.4s;
}

@keyframes typing {
  0%, 60%, 100% {
    transform: translateY(0);
    opacity: 0.7;
  }
  30% {
    transform: translateY(-10px);
    opacity: 1;
  }
}

.message-form {
  border-top: 1px solid #e2e8f0;
  padding: 1rem 1.5rem;
  background-color: #f7fafc;
}

.input-container {
  display: flex;
  gap: 0.75rem;
  align-items: flex-end;
}

textarea {
  flex: 1;
  padding: 0.75rem 1rem;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  font-family: inherit;
  font-size: 0.875rem;
  resize: none;
  min-height: 40px;
  max-height: 200px;
  line-height: 1.5;
}

textarea:focus {
  outline: none;
  border-color: #4299e1;
  box-shadow: 0 0 0 3px rgba(66, 153, 225, 0.1);
}

textarea:disabled {
  background-color: #f7fafc;
  cursor: not-allowed;
}

.send-btn {
  flex-shrink: 0;
  width: 40px;
  height: 40px;
  background-color: #4299e1;
  border: none;
  border-radius: 6px;
  color: white;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: background-color 0.2s;
}

.send-btn:hover:not(:disabled) {
  background-color: #3182ce;
}

.send-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.send-btn svg {
  width: 20px;
  height: 20px;
  stroke-width: 2;
}

.input-hint {
  margin: 0.5rem 0 0 0;
  font-size: 0.75rem;
  color: #a0aec0;
}

.error-message {
  margin: 1rem 1.5rem;
  padding: 0.75rem 1rem;
  background-color: #fed7d7;
  color: #c53030;
  border-radius: 6px;
  font-size: 0.875rem;
}
</style>
