<template>
  <div class="login-container">
    <div class="login-card">
      <div class="login-header">
        <h1>🎹 Ragtime</h1>
        <p class="tagline">Document Q&A System</p>
      </div>

      <form @submit.prevent="handleLogin" class="login-form">
        <div class="form-group">
          <label for="password">Access Password</label>
          <input
            id="password"
            v-model="password"
            type="password"
            placeholder="Enter password"
            :disabled="loading"
            autofocus
            autocomplete="off"
          />
        </div>

        <button type="submit" :disabled="!password.trim() || loading" class="login-btn">
          <span v-if="loading">Authenticating...</span>
          <span v-else>Access Demo</span>
        </button>

        <div v-if="error" class="error-message">
          <svg class="error-icon" viewBox="0 0 24 24" fill="none">
            <circle cx="12" cy="12" r="10" stroke="#c53030" stroke-width="2"></circle>
            <line x1="12" y1="8" x2="12" y2="12" stroke="#c53030" stroke-width="2" stroke-linecap="round"></line>
            <line x1="12" y1="16" x2="12.01" y2="16" stroke="#c53030" stroke-width="2" stroke-linecap="round"></line>
          </svg>
          <span>{{ error }}</span>
        </div>
      </form>

      <div class="login-footer">
        <p>This is a portfolio project by Tracy. Password available upon request.</p>
        <p class="contact-hint">Potential employers: Check your email or contact me for access.</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { useAuth } from '../composables/useAuth';

const router = useRouter();
const { login } = useAuth();
const password = ref('');
const loading = ref(false);
const error = ref('');

async function handleLogin() {
  if (!password.value.trim()) return;

  loading.value = true;
  error.value = '';

  try {
    await login(password.value);
    // Redirect to home page on successful login
    router.push('/');
  } catch (err) {
    error.value = err.response?.data?.error || 'Invalid password. Please try again.';
    password.value = '';
  } finally {
    loading.value = false;
  }
}
</script>

<style scoped>
.login-container {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 1rem;
}

.login-card {
  background: white;
  border-radius: 12px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  width: 100%;
  max-width: 420px;
  overflow: hidden;
}

.login-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 2.5rem 2rem 2rem;
  text-align: center;
}

.login-header h1 {
  margin: 0 0 0.5rem;
  font-size: 2.5rem;
  font-weight: 700;
}

.tagline {
  margin: 0;
  font-size: 1rem;
  opacity: 0.95;
  font-weight: 400;
}

.login-form {
  padding: 2rem;
}

.form-group {
  margin-bottom: 1.5rem;
}

.form-group label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 500;
  color: #2d3748;
  font-size: 0.875rem;
}

.form-group input {
  width: 100%;
  padding: 0.75rem 1rem;
  border: 2px solid #e2e8f0;
  border-radius: 6px;
  font-size: 1rem;
  transition: all 0.2s;
  box-sizing: border-box;
}

.form-group input:focus {
  outline: none;
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.form-group input:disabled {
  background-color: #f7fafc;
  cursor: not-allowed;
  opacity: 0.6;
}

.login-btn {
  width: 100%;
  padding: 0.875rem 1.5rem;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border: none;
  border-radius: 6px;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.login-btn:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
}

.login-btn:active:not(:disabled) {
  transform: translateY(0);
}

.login-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.error-message {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-top: 1rem;
  padding: 0.75rem 1rem;
  background-color: #fff5f5;
  border: 1px solid #feb2b2;
  border-left: 4px solid #c53030;
  border-radius: 6px;
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

.error-icon {
  flex-shrink: 0;
  width: 16px;
  height: 16px;
}

.error-message span {
  color: #742a2a;
  font-size: 0.875rem;
  line-height: 1.5;
}

.login-footer {
  padding: 1.5rem 2rem 2rem;
  background-color: #f7fafc;
  border-top: 1px solid #e2e8f0;
  text-align: center;
}

.login-footer p {
  margin: 0 0 0.5rem;
  font-size: 0.875rem;
  color: #4a5568;
  line-height: 1.5;
}

.login-footer p:last-child {
  margin-bottom: 0;
}

.contact-hint {
  color: #718096;
  font-size: 0.8125rem;
}
</style>
