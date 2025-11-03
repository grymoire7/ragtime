import axios from 'axios';

const api = axios.create({
  baseURL: import.meta.env.DEV ? '' : '/api',  // Use proxy in dev, /api in production
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  }
});

export const documentsAPI = {
  // Get all documents
  getAll() {
    return api.get('/documents');
  },

  // Get single document with chunks
  get(id) {
    return api.get(`/documents/${id}`);
  },

  // Upload a new document
  upload(file) {
    const formData = new FormData();
    formData.append('document[file]', file);

    return api.post('/documents', formData, {
      headers: {
        'Content-Type': 'multipart/form-data'
      }
    });
  },

  // Delete a document
  delete(id) {
    return api.delete(`/documents/${id}`);
  }
};

export const chatsAPI = {
  // Get all chats
  getAll() {
    return api.get('/chats');
  },

  // Get single chat with messages
  get(id) {
    return api.get(`/chats/${id}`);
  },

  // Create new chat
  create() {
    return api.post('/chats');
  },

  // Send a message in a chat
  sendMessage(chatId, content, options = {}) {
    const payload = {
      message: { content }
    };

    // Add optional filter parameters
    if (options.created_after) {
      payload.created_after = options.created_after;
    }

    return api.post(`/chats/${chatId}/messages`, payload);
  }
};

export const modelsAPI = {
  // Get available models
  getAll() {
    return api.get('/models');
  }
};

export default api;
