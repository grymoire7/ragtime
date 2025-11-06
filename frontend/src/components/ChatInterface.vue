<template>
  <div class="chat-interface">
    <div class="chat-header">
      <h2>Ask Questions</h2>
      <div v-if="currentChat" class="chat-actions">
        <button @click="startNewChat" class="new-chat-btn">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor">
            <path d="M12 5v14M5 12h14"/>
          </svg>
          New Chat
        </button>
        <div class="dropdown">
          <button @click="showMenu = !showMenu" class="menu-btn">
            ⋮
          </button>
          <div v-if="showMenu" class="dropdown-menu">
            <button @click="clearConversation" class="dropdown-item">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor">
                <polyline points="3 6 5 6 21 6"></polyline>
                <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
              </svg>
              Clear messages
            </button>
            <button @click="deleteConversation" class="dropdown-item danger">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor">
                <polyline points="3 6 5 6 21 6"></polyline>
                <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
                <line x1="10" y1="11" x2="10" y2="17"></line>
                <line x1="14" y1="11" x2="14" y2="17"></line>
              </svg>
              Delete conversation
            </button>
          </div>
        </div>
      </div>
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
      <div class="filter-bar">
        <label class="filter-checkbox">
          <input type="checkbox" v-model="filterRecentOnly" />
          <span class="checkbox-label">
            <svg class="checkbox-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor">
              <path d="M9 11l3 3L22 4"></path>
              <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"></path>
            </svg>
            Search recent documents only (last 7 days)
          </span>
        </label>
        <span v-if="filterRecentOnly" class="filter-active-badge">
          Filter active
        </span>
      </div>

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
            <div v-if="message.role === 'assistant' && hasEmptyContext(message)"
                 class="empty-context-box"
                 :class="`empty-context-${getEmptyContextType(message)}`">
              <svg class="info-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                <circle cx="12" cy="12" r="10"></circle>
                <line x1="12" y1="16" x2="12" y2="12"></line>
                <line x1="12" y1="8" x2="12.01" y2="8"></line>
              </svg>
              <div class="empty-context-content">
                <div class="empty-context-title">{{ getEmptyContextTitle(message) }}</div>
                <div class="empty-context-description">{{ message.content }}</div>
                <div v-if="getEmptyContextType(message) === 'no_recent_documents'" class="empty-context-action">
                  Try turning off the "Recent documents only" filter above.
                </div>
              </div>
            </div>
            <div v-else class="message-text">{{ message.content }}</div>
            <div v-if="message.role === 'assistant' && hasCitations(message)" class="citations">
              <div class="citations-header">Sources:</div>
              <div class="citations-list">
                <router-link
                  v-for="(citation, index) in getCitations(message)"
                  :key="index"
                  :to="getCitationLink(citation)"
                  class="citation-item"
                >
                  <span class="citation-number">[{{ index + 1 }}]</span>
                  <span class="citation-title">{{ formatCitationTitle(citation) }}</span>
                  <span class="citation-relevance">(relevance: {{ formatRelevance(citation.relevance) }})</span>
                  <svg class="citation-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                    <path d="M9 5l7 7-7 7"/>
                  </svg>
                </router-link>
              </div>
            </div>
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
            ▶
          </button>
        </div>
        <p class="input-hint">Press Enter to send, Shift+Enter for new line</p>
      </form>
    </div>

    <div v-if="error" class="error-banner">
      <div class="error-content">
        <svg class="error-icon" viewBox="0 0 24 24" fill="none">
          <circle cx="12" cy="12" r="10" stroke="#c53030" stroke-width="2"></circle>
          <line x1="12" y1="8" x2="12" y2="12" stroke="#c53030" stroke-width="2" stroke-linecap="round"></line>
          <line x1="12" y1="16" x2="12.01" y2="16" stroke="#c53030" stroke-width="2" stroke-linecap="round"></line>
        </svg>
        <span>{{ error }}</span>
      </div>
      <button @click="error = ''" class="dismiss-btn" aria-label="Dismiss error">
        ×
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, nextTick, watch, onActivated, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { chatsAPI } from '../services/api';
const router = useRouter();

const currentChat = ref(null);
const messages = ref([]);
const messageInput = ref('');
const sending = ref(false);
const loading = ref(false);
const error = ref('');
const messagesContainer = ref(null);
const textarea = ref(null);
const filterRecentOnly = ref(false);
const showMenu = ref(false);

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
    // Build options for message request
    const options = {};
    if (filterRecentOnly.value) {
      // Calculate date 7 days ago
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
      options.created_after = sevenDaysAgo.toISOString();
    }

    // Send message to API with filter options
    await chatsAPI.sendMessage(currentChat.value.id, content, options);

    // Poll for updates since the response is generated asynchronously
    // Poll every 500ms for up to 30 seconds
    const maxAttempts = 60;
    let attempts = 0;
    const initialMessageCount = messages.value.length;

    const pollInterval = setInterval(async () => {
      attempts++;

      try {
        await loadChat(currentChat.value.id);

        // Check if we have a NEW assistant response (more messages than when we started)
        const hasNewAssistantResponse = messages.value.length > initialMessageCount &&
          messages.value.some(
            msg => msg.role === 'assistant' && msg.content && msg.content.trim().length > 0
          );

        // Stop polling if we got a new assistant response with content or reached max attempts
        if (hasNewAssistantResponse || attempts >= maxAttempts) {
          clearInterval(pollInterval);
          sending.value = false;

          if (!hasNewAssistantResponse && attempts >= maxAttempts) {
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
  showMenu.value = false;
}

async function clearConversation() {
  if (!confirm('Clear all messages from this conversation?')) {
    return;
  }

  showMenu.value = false;
  error.value = '';

  try {
    await chatsAPI.clear(currentChat.value.id);
    messages.value = [];
  } catch (err) {
    error.value = 'Failed to clear conversation. Please try again.';
    console.error('Error clearing conversation:', err);
  }
}

async function deleteConversation() {
  if (!confirm('Delete this conversation permanently? This cannot be undone.')) {
    return;
  }

  showMenu.value = false;
  error.value = '';

  try {
    await chatsAPI.delete(currentChat.value.id);
    startNewChat();
  } catch (err) {
    error.value = 'Failed to delete conversation. Please try again.';
    console.error('Error deleting conversation:', err);
  }
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

function hasCitations(message) {
  return message.metadata &&
         message.metadata.citations &&
         Array.isArray(message.metadata.citations) &&
         message.metadata.citations.length > 0;
}

function getCitations(message) {
  return message.metadata?.citations || [];
}

function formatRelevance(relevance) {
  if (typeof relevance === 'number') {
    return `${Math.round(relevance * 100)}%`;
  }
  return 'N/A';
}

function formatCitationTitle(citation) {
  let title = citation.document_title;

  // Add chunk position if available to distinguish multiple citations from same document
  if (citation.position !== undefined && citation.position !== null) {
    title += ` (Chunk #${citation.position + 1})`;
  }

  return title;
}

function getCitationLink(citation) {
  const path = `/documents/${citation.document_id}`;
  const query = citation.chunk_id ? { highlight: citation.chunk_id } : {};
  return { path, query };
}

function hasEmptyContext(message) {
  return message.metadata &&
         message.metadata.empty_context &&
         message.metadata.empty_context.type;
}

function getEmptyContextType(message) {
  return message.metadata?.empty_context?.type || null;
}

function getEmptyContextTitle(message) {
  const type = getEmptyContextType(message);
  const titles = {
    no_documents: 'No Documents Found',
    no_recent_documents: 'No Recent Documents Found',
    no_relevant_chunks: 'No Relevant Information Found'
  };
  return titles[type] || 'No Results';
}

watch(messages, () => {
  scrollToBottom();
});

// Close dropdown when clicking outside
function handleClickOutside(event) {
  const dropdown = event.target.closest('.dropdown');
  if (!dropdown && showMenu.value) {
    showMenu.value = false;
  }
}

onMounted(() => {
  document.addEventListener('click', handleClickOutside);
});

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside);
});

// Scroll to bottom when returning from document detail view
onActivated(() => {
  if (currentChat.value && messages.value.length > 0) {
    scrollToBottom();
  }
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

.chat-actions {
  display: flex;
  gap: 0.5rem;
  align-items: center;
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

.dropdown {
  position: relative;
}

.menu-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  background-color: white;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  color: #4a5568;
  cursor: pointer;
  transition: all 0.2s;
  font-size: 20px;
  font-weight: 700;
  line-height: 1;
  font-family: Arial, sans-serif;
}

.menu-btn:hover {
  background-color: #edf2f7;
  border-color: #cbd5e0;
}

.dropdown-menu {
  position: absolute;
  top: calc(100% + 0.5rem);
  right: 0;
  min-width: 200px;
  background-color: white;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  z-index: 10;
  overflow: hidden;
}

.dropdown-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  width: 100%;
  padding: 0.75rem 1rem;
  background-color: transparent;
  border: none;
  color: #2d3748;
  font-size: 0.875rem;
  text-align: left;
  cursor: pointer;
  transition: all 0.2s;
}

.dropdown-item:hover {
  background-color: #f7fafc;
}

.dropdown-item.danger {
  color: #c53030;
}

.dropdown-item.danger:hover {
  background-color: #fff5f5;
}

.dropdown-item svg {
  width: 16px;
  height: 16px;
  stroke-width: 2;
}

.dropdown-divider {
  height: 1px;
  background-color: #e2e8f0;
  margin: 0.5rem 0;
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

.filter-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.75rem 1.5rem;
  background-color: #faf5ff;
  border-bottom: 1px solid #e9d5ff;
}

.filter-checkbox {
  display: flex;
  align-items: center;
  cursor: pointer;
  user-select: none;
}

.filter-checkbox input[type="checkbox"] {
  margin-right: 0.5rem;
  cursor: pointer;
  width: 16px;
  height: 16px;
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  color: #6b46c1;
  font-weight: 500;
}

.checkbox-icon {
  width: 16px;
  height: 16px;
  stroke-width: 2;
  color: #9f7aea;
}

.filter-active-badge {
  padding: 0.25rem 0.75rem;
  background-color: #9f7aea;
  color: white;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 500;
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
  text-align: left;
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

.citations {
  margin-top: 0.75rem;
  padding: 0.75rem;
  background-color: #edf2f7;
  border-radius: 6px;
  border-left: 3px solid #9f7aea;
}

.citations-header {
  font-size: 0.75rem;
  font-weight: 600;
  color: #4a5568;
  margin-bottom: 0.5rem;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.citations-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.citation-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  line-height: 1.4;
  text-decoration: none;
  color: inherit;
  padding: 0.5rem;
  margin: 0 -0.5rem;
  border-radius: 4px;
  transition: all 0.2s;
  cursor: pointer;
}

.citation-item:hover {
  background-color: #e6fffa;
  transform: translateX(4px);
}

.citation-number {
  font-weight: 600;
  color: #9f7aea;
  flex-shrink: 0;
}

.citation-title {
  color: #2d3748;
  font-weight: 500;
  flex: 1;
}

.citation-relevance {
  color: #718096;
  font-size: 0.8125rem;
}

.citation-icon {
  width: 14px;
  height: 14px;
  stroke-width: 2;
  color: #9f7aea;
  flex-shrink: 0;
  opacity: 0;
  transition: opacity 0.2s;
}

.citation-item:hover .citation-icon {
  opacity: 1;
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
  font-size: 18px;
  line-height: 1;
  font-family: Arial, sans-serif;
}

.send-btn:hover:not(:disabled) {
  background-color: #3182ce;
}

.send-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.input-hint {
  margin: 0.5rem 0 0 0;
  font-size: 0.75rem;
  color: #a0aec0;
}

.error-banner {
  margin: 1rem 1.5rem;
  padding: 0.75rem 1rem;
  background-color: #fed7d7;
  color: #c53030;
  border-radius: 6px;
  border-left: 4px solid #c53030;
  font-size: 0.875rem;
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 1rem;
  animation: slideIn 0.3s ease-out;
}

@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateY(-10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.error-content {
  display: flex;
  align-items: flex-start;
  gap: 0.75rem;
  flex: 1;
}

.error-icon {
  flex-shrink: 0;
  width: 20px;
  height: 20px;
  margin-top: 1px;
}

.error-icon circle,
.error-icon line {
  stroke: #c53030;
  stroke-width: 2;
  stroke-linecap: round;
}

.dismiss-btn {
  flex-shrink: 0;
  background: none;
  border: none;
  color: #c53030;
  cursor: pointer;
  padding: 0;
  width: 24px;
  height: 24px;
  opacity: 0.7;
  transition: opacity 0.2s;
  font-size: 20px;
  font-weight: 400;
  line-height: 1;
  font-family: Arial, sans-serif;
  display: flex;
  align-items: center;
  justify-content: center;
}

.dismiss-btn:hover {
  opacity: 1;
  background-color: rgba(254, 215, 215, 0.5);
  border-radius: 4px;
}

.empty-context-box {
  display: flex;
  gap: 0.75rem;
  padding: 1rem;
  border-radius: 8px;
  border: 1px solid #e2e8f0;
}

.empty-context-box .info-icon {
  flex-shrink: 0;
  width: 20px;
  height: 20px;
  stroke-width: 2;
  margin-top: 2px;
}

.empty-context-content {
  flex: 1;
}

.empty-context-title {
  font-weight: 600;
  font-size: 0.9375rem;
  margin-bottom: 0.5rem;
}

.empty-context-description {
  font-size: 0.875rem;
  line-height: 1.5;
  margin-bottom: 0.5rem;
}

.empty-context-action {
  font-size: 0.8125rem;
  font-style: italic;
  opacity: 0.8;
}

/* Variant: No documents */
.empty-context-no_documents {
  background-color: #fff5f5;
  border-color: #feb2b2;
}

.empty-context-no_documents .info-icon {
  color: #c53030;
}

.empty-context-no_documents .empty-context-title {
  color: #742a2a;
}

.empty-context-no_documents .empty-context-description {
  color: #9b2c2c;
}

/* Variant: No recent documents */
.empty-context-no_recent_documents {
  background-color: #fefcbf;
  border-color: #f6e05e;
}

.empty-context-no_recent_documents .info-icon {
  color: #d69e2e;
}

.empty-context-no_recent_documents .empty-context-title {
  color: #744210;
}

.empty-context-no_recent_documents .empty-context-description {
  color: #975a16;
}

.empty-context-no_recent_documents .empty-context-action {
  color: #744210;
}

/* Variant: No relevant chunks */
.empty-context-no_relevant_chunks {
  background-color: #e6fffa;
  border-color: #81e6d9;
}

.empty-context-no_relevant_chunks .info-icon {
  color: #319795;
}

.empty-context-no_relevant_chunks .empty-context-title {
  color: #234e52;
}

.empty-context-no_relevant_chunks .empty-context-description {
  color: #2c7a7b;
}
</style>
