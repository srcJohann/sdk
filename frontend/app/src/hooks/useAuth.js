import { useState, useEffect } from 'react';

/**
 * Hook personalizado para gerenciar autenticação
 * Salva e recupera o estado de autenticação do localStorage/sessionStorage
 */
const useAuth = () => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [user, setUser] = useState(null);
  const [isLoading, setIsLoading] = useState(true);

  // Verificar autenticação ao carregar
  useEffect(() => {
    checkAuth();
  }, []);

  const checkAuth = () => {
    try {
      // Verificar localStorage primeiro (remember me)
      const rememberMe = localStorage.getItem('auth_remember') === 'true';
      let token = null;
      let username = null;

      if (rememberMe) {
        token = localStorage.getItem('auth_token');
        username = localStorage.getItem('auth_username');
      } else {
        // Verificar sessionStorage
        token = sessionStorage.getItem('auth_token');
        username = sessionStorage.getItem('auth_username');
      }

      if (token && username) {
        setIsAuthenticated(true);
        setUser({
          username,
          token,
          rememberMe
        });
      }
    } catch (error) {
      console.error('Erro ao verificar autenticação:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const login = (userData) => {
    setIsAuthenticated(true);
    setUser(userData);
  };

  const logout = () => {
    // Limpar localStorage
    localStorage.removeItem('auth_token');
    localStorage.removeItem('auth_username');
    localStorage.removeItem('auth_remember');
    
    // Limpar sessionStorage
    sessionStorage.removeItem('auth_token');
    sessionStorage.removeItem('auth_username');

    setIsAuthenticated(false);
    setUser(null);
  };

  return {
    isAuthenticated,
    user,
    isLoading,
    login,
    logout,
    checkAuth
  };
};

export default useAuth;
