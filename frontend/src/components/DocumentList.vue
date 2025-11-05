<template>
  <div class="document-list">
    <div class="header">
      <h2>Documents</h2>
      <button v-if="documents.length > 0" @click="refresh" class="refresh-btn" :disabled="loading">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor">
          <polyline points="23 4 23 10 17 10"></polyline>
          <polyline points="1 20 1 14 7 14"></polyline>
          <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"></path>
        </svg>
        Refresh
      </button>
    </div>

    <div v-if="loading && documents.length === 0" class="loading">
      <div class="spinner"></div>
      <p>Loading documents...</p>
    </div>

    <div v-else-if="error" class="error-banner">
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

    <div v-else-if="documents.length === 0" class="empty-state">
      <svg class="empty-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor">
        <path d="M13 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"></path>
        <polyline points="13 2 13 9 20 9"></polyline>
      </svg>
      <p>No documents uploaded yet</p>
      <p class="empty-subtext">Upload your first document to get started</p>
    </div>

    <div v-else class="documents-grid">
      <div
        v-for="doc in documents"
        :key="doc.id"
        class="document-card"
        :class="{'processing': doc.status === 'processing' || doc.status === 'pending'}"
      >
        <div class="document-header">
          <div class="document-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor">
              <path d="M13 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"></path>
              <polyline points="13 2 13 9 20 9"></polyline>
            </svg>
          </div>
          <div class="document-info">
            <h3 class="document-title" :title="doc.title">{{ doc.title }}</h3>
            <p class="document-meta">{{ formatFileSize(doc.file_size) }} • {{ formatDate(doc.created_at) }}</p>
          </div>
          <button
            @click="deleteDocument(doc.id)"
            class="delete-btn"
            :disabled="deleting === doc.id"
            title="Delete document"
          >
            🗑️
          </button>
        </div>

        <div class="document-status">
          <span
            class="status-badge"
            :class="`status-${doc.status}`"
          >
            <span v-if="doc.status === 'processing' || doc.status === 'pending'" class="status-spinner"></span>
            {{ formatStatus(doc.status) }}
          </span>
          <span v-if="doc.chunk_count" class="chunk-count">
            {{ doc.chunk_count }} chunk{{ doc.chunk_count !== 1 ? 's' : '' }}
          </span>
        </div>

        <div v-if="doc.status === 'failed' && doc.error_message" class="error-details">
          <svg class="error-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor">
            <circle cx="12" cy="12" r="10"></circle>
            <line x1="12" y1="8" x2="12" y2="12"></line>
            <line x1="12" y1="16" x2="12.01" y2="16"></line>
          </svg>
          <span class="error-text">{{ doc.error_message }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { documentsAPI } from '../services/api';

const documents = ref([]);
const loading = ref(false);
const error = ref('');
const deleting = ref(null);

async function loadDocuments() {
  loading.value = true;
  error.value = '';

  try {
    const response = await documentsAPI.getAll();
    documents.value = response.data;
  } catch (err) {
    error.value = 'Failed to load documents. Please try again.';
    console.error('Error loading documents:', err);
  } finally {
    loading.value = false;
  }
}

async function refresh() {
  await loadDocuments();
}

async function deleteDocument(id) {
  if (!confirm('Are you sure you want to delete this document?')) {
    return;
  }

  deleting.value = id;

  try {
    await documentsAPI.delete(id);
    documents.value = documents.value.filter(doc => doc.id !== id);
  } catch (err) {
    error.value = 'Failed to delete document. Please try again.';
    console.error('Error deleting document:', err);
  } finally {
    deleting.value = null;
  }
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
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
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

onMounted(() => {
  loadDocuments();
});

// Auto-refresh every 5 seconds if there are processing documents
let refreshInterval;
onMounted(() => {
  refreshInterval = setInterval(() => {
    const hasProcessing = documents.value.some(doc =>
      doc.status === 'processing' || doc.status === 'pending'
    );
    if (hasProcessing) {
      loadDocuments();
    }
  }, 5000);
});

// Clean up interval on unmount
import { onUnmounted } from 'vue';
onUnmounted(() => {
  if (refreshInterval) {
    clearInterval(refreshInterval);
  }
});

defineExpose({ refresh: loadDocuments });
</script>

<style scoped>
.document-list {
  margin-bottom: 2rem;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.5rem;
}

.header h2 {
  margin: 0;
  font-size: 1.5rem;
  font-weight: 600;
  color: #2d3748;
}

.refresh-btn {
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

.refresh-btn:hover:not(:disabled) {
  background-color: #f7fafc;
  border-color: #cbd5e0;
}

.refresh-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.refresh-btn svg {
  width: 16px;
  height: 16px;
  stroke-width: 2;
}

.loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  padding: 3rem;
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

.error-banner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem;
  background-color: #fff5f5;
  border: 1px solid #feb2b2;
  border-left: 4px solid #c53030;
  border-radius: 6px;
  margin-bottom: 1.5rem;
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
  align-items: center;
  gap: 0.75rem;
  flex: 1;
}

.error-content span {
  color: #742a2a;
  font-size: 0.875rem;
  line-height: 1.5;
}

.error-banner .error-icon {
  flex-shrink: 0;
  width: 16px;
  height: 16px;
}

.error-banner .error-icon circle,
.error-banner .error-icon line {
  stroke: #c53030;
  stroke-width: 2;
  stroke-linecap: round;
}

.dismiss-btn {
  flex-shrink: 0;
  width: 24px;
  height: 24px;
  background-color: transparent;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
  color: #c53030;
  font-size: 20px;
  font-weight: 400;
  line-height: 1;
  font-family: Arial, sans-serif;
}

.dismiss-btn:hover {
  background-color: #fed7d7;
}

.empty-state {
  text-align: center;
  padding: 3rem;
  color: #718096;
}

.empty-icon {
  width: 64px;
  height: 64px;
  margin: 0 auto 1rem;
  stroke-width: 1.5;
}

.empty-state p {
  margin: 0.5rem 0;
  font-size: 1.125rem;
}

.empty-subtext {
  font-size: 0.875rem !important;
  color: #a0aec0;
}

.documents-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1rem;
}

.document-card {
  background-color: white;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 1.25rem;
  transition: all 0.2s;
}

.document-card:hover {
  border-color: #cbd5e0;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
}

.document-card.processing {
  background-color: #faf5ff;
  border-color: #d6bcfa;
}

.document-header {
  display: flex;
  gap: 0.75rem;
  margin-bottom: 1rem;
}

.document-icon {
  flex-shrink: 0;
  width: 40px;
  height: 40px;
  background-color: #edf2f7;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.document-icon svg {
  width: 24px;
  height: 24px;
  stroke-width: 2;
  color: #4a5568;
}

.document-info {
  flex: 1;
  min-width: 0;
}

.document-title {
  margin: 0 0 0.25rem 0;
  font-size: 1rem;
  font-weight: 600;
  color: #2d3748;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.document-meta {
  margin: 0;
  font-size: 0.75rem;
  color: #718096;
}

.delete-btn {
  flex-shrink: 0;
  width: 32px;
  height: 32px;
  background-color: transparent;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
  font-size: 18px;
  line-height: 1;
}

.delete-btn:hover:not(:disabled) {
  background-color: #fed7d7;
  transform: scale(1.1);
}

.delete-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.document-status {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.status-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
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

.status-spinner {
  display: inline-block;
  width: 12px;
  height: 12px;
  border: 2px solid currentColor;
  border-top-color: transparent;
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}

.chunk-count {
  font-size: 0.75rem;
  color: #718096;
}

.error-details {
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
  margin-top: 0.75rem;
  padding: 0.75rem;
  background-color: #fff5f5;
  border: 1px solid #feb2b2;
  border-radius: 6px;
}

.error-icon {
  flex-shrink: 0;
  width: 16px;
  height: 16px;
  stroke-width: 2;
  color: #c53030;
  margin-top: 1px;
}

.error-text {
  font-size: 0.8125rem;
  color: #742a2a;
  line-height: 1.5;
}
</style>
