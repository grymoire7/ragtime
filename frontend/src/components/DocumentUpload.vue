<template>
  <div class="document-upload">
    <div
      class="drop-zone"
      :class="{ 'drag-over': isDragOver, 'uploading': uploading }"
      @drop.prevent="handleDrop"
      @dragover.prevent="isDragOver = true"
      @dragleave.prevent="isDragOver = false"
    >
      <div v-if="!uploading" class="drop-zone-content">
        <svg class="upload-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor">
          <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
          <polyline points="17 8 12 3 7 8"></polyline>
          <line x1="12" y1="3" x2="12" y2="15"></line>
        </svg>
        <p class="drop-text">
          Drag and drop documents here
        </p>
        <p class="drop-subtext">or</p>
        <label for="file-input" class="file-label">
          Browse files
          <input
            id="file-input"
            type="file"
            accept=".pdf,.txt,.docx"
            @change="handleFileSelect"
            hidden
          >
        </label>
        <p class="supported-formats">Supported: PDF, TXT, DOCX</p>
      </div>

      <div v-else class="uploading-content">
        <div class="spinner"></div>
        <p>Uploading {{ uploadingFileName }}...</p>
      </div>
    </div>

    <div v-if="error" class="error-message">
      {{ error }}
    </div>

    <div v-if="successMessage" class="success-message">
      {{ successMessage }}
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import { documentsAPI } from '../services/api';

const emit = defineEmits(['upload-success']);

const isDragOver = ref(false);
const uploading = ref(false);
const uploadingFileName = ref('');
const error = ref('');
const successMessage = ref('');

const SUPPORTED_TYPES = [
  'application/pdf',
  'text/plain',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
];

function handleDrop(e) {
  isDragOver.value = false;
  const files = e.dataTransfer.files;
  if (files.length > 0) {
    uploadFile(files[0]);
  }
}

function handleFileSelect(e) {
  const files = e.target.files;
  if (files.length > 0) {
    uploadFile(files[0]);
  }
}

async function uploadFile(file) {
  error.value = '';
  successMessage.value = '';

  // Validate file type
  if (!SUPPORTED_TYPES.includes(file.type)) {
    error.value = 'Unsupported file format. Please upload PDF, TXT, or DOCX files.';
    return;
  }

  // Validate file size (max 50MB)
  const maxSize = 50 * 1024 * 1024; // 50MB in bytes
  if (file.size > maxSize) {
    error.value = 'File is too large. Maximum size is 50MB.';
    return;
  }

  uploading.value = true;
  uploadingFileName.value = file.name;

  try {
    const response = await documentsAPI.upload(file);
    successMessage.value = `Successfully uploaded ${file.name}. Processing...`;
    emit('upload-success', response.data);

    // Clear success message after 3 seconds
    setTimeout(() => {
      successMessage.value = '';
    }, 3000);

  } catch (err) {
    error.value = err.response?.data?.error || 'Failed to upload document. Please try again.';
  } finally {
    uploading.value = false;
    uploadingFileName.value = '';
    // Reset file input
    document.getElementById('file-input').value = '';
  }
}
</script>

<style scoped>
.document-upload {
  margin-bottom: 2rem;
}

.drop-zone {
  border: 2px dashed #cbd5e0;
  border-radius: 8px;
  padding: 3rem 2rem;
  text-align: center;
  background-color: #f7fafc;
  transition: all 0.2s ease;
  cursor: pointer;
}

.drop-zone.drag-over {
  border-color: #4299e1;
  background-color: #ebf8ff;
}

.drop-zone.uploading {
  border-color: #9f7aea;
  background-color: #faf5ff;
  cursor: not-allowed;
}

.drop-zone-content,
.uploading-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
}

.upload-icon {
  width: 48px;
  height: 48px;
  color: #718096;
}

.drop-text {
  font-size: 1.125rem;
  font-weight: 500;
  color: #2d3748;
  margin: 0;
}

.drop-subtext {
  color: #718096;
  margin: 0;
}

.file-label {
  display: inline-block;
  padding: 0.75rem 1.5rem;
  background-color: #4299e1;
  color: white;
  border-radius: 6px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;
}

.file-label:hover {
  background-color: #3182ce;
}

.supported-formats {
  font-size: 0.875rem;
  color: #718096;
  margin: 0;
}

.spinner {
  border: 3px solid #e2e8f0;
  border-top-color: #9f7aea;
  border-radius: 50%;
  width: 40px;
  height: 40px;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.uploading-content p {
  color: #9f7aea;
  font-weight: 500;
}

.error-message {
  margin-top: 1rem;
  padding: 0.75rem 1rem;
  background-color: #fed7d7;
  color: #c53030;
  border-radius: 6px;
  font-size: 0.875rem;
}

.success-message {
  margin-top: 1rem;
  padding: 0.75rem 1rem;
  background-color: #c6f6d5;
  color: #22543d;
  border-radius: 6px;
  font-size: 0.875rem;
}
</style>
