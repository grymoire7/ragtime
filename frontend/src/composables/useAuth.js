import { ref } from 'vue';
import { authAPI } from '../services/api';

const isAuthenticated = ref(false);
const isChecking = ref(true);

export function useAuth() {
  async function checkAuth() {
    isChecking.value = true;
    try {
      const response = await authAPI.checkStatus();
      isAuthenticated.value = response.data.authenticated;
    } catch (error) {
      isAuthenticated.value = false;
    } finally {
      isChecking.value = false;
    }
  }

  async function login(password) {
    await authAPI.login(password);
    isAuthenticated.value = true;
  }

  async function logout() {
    await authAPI.logout();
    isAuthenticated.value = false;
  }

  return {
    isAuthenticated,
    isChecking,
    checkAuth,
    login,
    logout
  };
}
