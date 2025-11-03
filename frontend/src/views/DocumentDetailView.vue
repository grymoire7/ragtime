<template>
  <div class="document-detail-view">
    <div class="container">
      <div class="back-nav">
        <button @click="goBack" class="back-btn">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor">
            <path d="M19 12H5M12 19l-7-7 7-7"/>
          </svg>
          Back to Chat
        </button>
      </div>

      <div v-if="loading" class="loading-state">
        <div class="spinner"></div>
        <p>Loading document...</p>
      </div>

      <div v-else-if="error" class="error-message">
        {{ error }}
      </div>

      <div v-else-if="document" class="document-content">
        <div class="document-header">
          <div class="document-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor">
              <path d="M13 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"></path>
              <polyline points="13 2 13 9 20 9"></polyline>
            </svg>
          </div>
          <div class="document-info">
            <h1 class="document-title">{{ document.title }}</h1>
            <div class="document-meta">
              <span>{{ formatFileSize(document.file_size) }}</span>
              <span>•</span>
              <span>{{ formatDate(document.created_at) }}</span>
              <span>•</span>
              <span class="status-badge" :class="`status-${document.status}`">
                {{ formatStatus(document.status) }}
              </span>
            </div>
          </div>
        </div>

        <div v-if="document.chunks && document.chunks.length > 0" class="chunks-section">
          <div v-if="highlightChunkId">
            <h2 class="chunks-header">
              Cited Chunk
            </h2>
            <p class="chunks-description">
              This is the specific chunk that was cited in the answer.
              <a
                v-if="document.chunks.length > 1"
                href="#"
                @click.prevent="showAllChunks = !showAllChunks"
                class="toggle-link"
              >
                {{ showAllChunks ? 'Hide context' : 'Show all context' }}
              </a>
            </p>
          </div>
          <div v-else>
            <h2 class="chunks-header">
              Document Chunks ({{ document.chunks.length }})
            </h2>
            <p class="chunks-description">
              This document has been split into {{ document.chunks.length }} chunks for semantic search.
            </p>
          </div>

          <div class="chunks-list">
            <div
              v-for="chunk in visibleChunks"
              :key="chunk.id"
              :id="`chunk-${chunk.id}`"
              class="chunk-card"
              :class="{
                'highlighted': chunk.id === highlightChunkId,
                'context-chunk': isContextChunk(chunk)
              }"
            >
              <div class="chunk-header">
                <span class="chunk-label">
                  Chunk #{{ chunk.position + 1 }}
                  <span v-if="chunk.id === highlightChunkId" class="cited-badge">CITED</span>
                </span>
                <span class="chunk-tokens">{{ chunk.token_count }} tokens</span>
              </div>
              <div class="chunk-content">
                {{ chunk.content }}
              </div>
            </div>
          </div>
        </div>

        <div v-else class="no-chunks">
          <p>No chunks available for this document.</p>
          <p class="subtext">The document may still be processing.</p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, nextTick, computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { documentsAPI } from '../services/api';

const route = useRoute();
const router = useRouter();

const document = ref(null);
const loading = ref(false);
const error = ref('');
const highlightChunkId = ref(null);
const showAllChunks = ref(false);

// Compute which chunks to show based on highlight and showAllChunks state
const visibleChunks = computed(() => {
  if (!document.value || !document.value.chunks) return [];

  const allChunks = document.value.chunks;

  // If no highlight or showAllChunks is true, show everything
  if (!highlightChunkId.value || showAllChunks.value) {
    return allChunks;
  }

  // Find the highlighted chunk
  const citedChunk = allChunks.find(c => c.id === highlightChunkId.value);

  if (!citedChunk) {
    // Highlighted chunk not found, show all
    return allChunks;
  }

  // Show ONLY the cited chunk by default
  return [citedChunk];
});

// Check if a chunk is a context chunk (shown for context, not cited)
// Only applies when showing all chunks - uncited chunks get subdued styling
function isContextChunk(chunk) {
  return highlightChunkId.value &&
         showAllChunks.value &&
         chunk.id !== highlightChunkId.value;
}

onMounted(async () => {
  const documentId = route.params.id;
  highlightChunkId.value = route.query.highlight ? parseInt(route.query.highlight) : null;

  await loadDocument(documentId);

  // Scroll to highlighted chunk after a short delay
  if (highlightChunkId.value) {
    await nextTick();
    setTimeout(() => {
      const element = document.getElementById(`chunk-${highlightChunkId.value}`);
      if (element) {
        element.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
    }, 100);
  }
});

async function loadDocument(id) {
  loading.value = true;
  error.value = '';

  try {
    const response = await documentsAPI.get(id);
    document.value = response.data;
  } catch (err) {
    error.value = 'Failed to load document. Please try again.';
    console.error('Error loading document:', err);
  } finally {
    loading.value = false;
  }
}

function goBack() {
  router.push('/');
  // Scroll to bottom of chat when returning (using nextTick to wait for navigation)
  nextTick(() => {
    // The ChatInterface component will handle scrolling when it's activated
  });
}

function formatFileSize(bytes) {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return Math.round(bytes / Math.pow(k, i) * 10) / 10 + ' ' + sizes[i];
}

function formatDate(dateString) {
  const date = new Date(dateString);
  return date.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
}

function formatStatus(status) {
  const statusMap = {
    pending: 'Pending',
    processing: 'Processing',
    completed: 'Ready',
    failed: 'Failed'
  };
  return statusMap[status] || status;
}
</script>

<style scoped>
.document-detail-view {
  padding: 2rem 0;
  min-height: calc(100vh - 200px);
}

.container {
  max-width: 900px;
  margin: 0 auto;
  padding: 0 2rem;
}

.back-nav {
  margin-bottom: 2rem;
}

.back-btn {
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

.back-btn:hover {
  background-color: #f7fafc;
  border-color: #cbd5e0;
}

.back-btn svg {
  width: 16px;
  height: 16px;
  stroke-width: 2;
}

.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  padding: 4rem 2rem;
  color: #718096;
}

.spinner {
  border: 3px solid #e2e8f0;
  border-top-color: #4299e1;
  border-radius: 50%;
  width: 40px;
  height: 40px;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.error-message {
  padding: 1rem;
  background-color: #fed7d7;
  color: #c53030;
  border-radius: 6px;
  font-size: 0.875rem;
}

.document-content {
  background-color: white;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  overflow: hidden;
}

.document-header {
  display: flex;
  gap: 1rem;
  padding: 2rem;
  border-bottom: 1px solid #e2e8f0;
  background-color: #f7fafc;
}

.document-icon {
  flex-shrink: 0;
  width: 64px;
  height: 64px;
  background-color: #edf2f7;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.document-icon svg {
  width: 36px;
  height: 36px;
  stroke-width: 2;
  color: #4a5568;
}

.document-info {
  flex: 1;
  min-width: 0;
}

.document-title {
  margin: 0 0 0.5rem 0;
  font-size: 1.75rem;
  font-weight: 600;
  color: #2d3748;
}

.document-meta {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  color: #718096;
  flex-wrap: wrap;
}

.status-badge {
  padding: 0.25rem 0.75rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 500;
}

.status-pending,
.status-processing {
  background-color: #faf089;
  color: #744210;
}

.status-completed {
  background-color: #c6f6d5;
  color: #22543d;
}

.status-failed {
  background-color: #fed7d7;
  color: #c53030;
}

.chunks-section {
  padding: 2rem;
}

.chunks-header {
  margin: 0 0 0.5rem 0;
  font-size: 1.25rem;
  font-weight: 600;
  color: #2d3748;
}

.chunks-description {
  margin: 0 0 2rem 0;
  font-size: 0.875rem;
  color: #718096;
  line-height: 1.5;
}

.toggle-link {
  color: #4299e1;
  text-decoration: none;
  font-weight: 500;
  margin-left: 0.5rem;
}

.toggle-link:hover {
  text-decoration: underline;
}

.chunks-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.chunk-card {
  background-color: #f7fafc;
  border: 2px solid #e2e8f0;
  border-radius: 6px;
  padding: 1rem;
  transition: all 0.3s;
}

.chunk-card.highlighted {
  background-color: #fefcbf;
  border-color: #f6ad55;
  box-shadow: 0 0 0 3px rgba(246, 173, 85, 0.2);
}

.chunk-card.context-chunk {
  background-color: #f7fafc;
  border-color: #cbd5e0;
  opacity: 0.8;
}

.chunk-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.75rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid #e2e8f0;
}

.chunk-label {
  font-weight: 600;
  color: #4a5568;
  font-size: 0.875rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.cited-badge {
  display: inline-block;
  padding: 0.125rem 0.5rem;
  background-color: #f6ad55;
  color: white;
  font-size: 0.625rem;
  font-weight: 700;
  border-radius: 9999px;
  letter-spacing: 0.5px;
}

.chunk-tokens {
  font-size: 0.75rem;
  color: #a0aec0;
}

.chunk-content {
  color: #2d3748;
  line-height: 1.6;
  white-space: pre-wrap;
  word-break: break-word;
}

.no-chunks {
  padding: 4rem 2rem;
  text-align: center;
  color: #718096;
}

.no-chunks p {
  margin: 0.5rem 0;
  font-size: 1rem;
}

.subtext {
  font-size: 0.875rem !important;
  color: #a0aec0;
}
</style>
