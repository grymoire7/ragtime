<template>
  <div class="chat-view">
    <div class="container">
      <section class="section">
        <h2 class="section-title">Upload Documents</h2>
        <DocumentUpload @upload-success="handleUploadSuccess" />
      </section>

      <div class="two-column">
        <section class="section">
          <DocumentList ref="documentList" />
        </section>

        <section class="section">
          <ChatInterface />
        </section>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import DocumentUpload from '../components/DocumentUpload.vue';
import DocumentList from '../components/DocumentList.vue';
import ChatInterface from '../components/ChatInterface.vue';

const documentList = ref(null);

function handleUploadSuccess() {
  // Refresh the document list when a new document is uploaded
  if (documentList.value) {
    documentList.value.refresh();
  }
}
</script>

<style scoped>
.chat-view {
  padding: 3rem 0;
}

.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 2rem;
}

.section {
  margin-bottom: 3rem;
}

.section-title {
  font-size: 1.5rem;
  font-weight: 600;
  color: #2d3748;
  margin: 0 0 1.5rem 0;
}

.two-column {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 2rem;
}

@media (max-width: 968px) {
  .two-column {
    grid-template-columns: 1fr;
  }
}
</style>
