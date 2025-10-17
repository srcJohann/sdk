/**
 * Authentication Context for DOM360
 * Manages user authentication state and role-based access
 */
import React, { createContext, useContext, useState, useEffect } from 'react';
import { jwtDecode } from 'jwt-decode';
// Use same base URL env as services
const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3001';

// User roles
export const UserRole = {
  MASTER: 'MASTER',
  TENANT_ADMIN: 'TENANT_ADMIN',
  TENANT_USER: 'TENANT_USER',
};

// Auth context
const AuthContext = createContext(null);

// Token storage
const TOKEN_KEY = 'dom360_auth_token';

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [token, setToken] = useState(null);
  const [loading, setLoading] = useState(true);

  // Initialize auth from localStorage or sessionStorage
  useEffect(() => {
    const storedToken = localStorage.getItem(TOKEN_KEY) || sessionStorage.getItem(TOKEN_KEY);
    if (storedToken) {
      try {
        const decoded = jwtDecode(storedToken);

        // Check if token is expired
        if (decoded.exp * 1000 < Date.now()) {
          logout();
        } else {
          setToken(storedToken);
          setUser({
            id: decoded.sub,
            tenantId: decoded.tenant_id,
            role: decoded.role,
            username: decoded.username,
            email: decoded.email,
          });
        }
      } catch (error) {
        console.error('Invalid token:', error);
        logout();
      }
    }
    setLoading(false);
  }, []);

  // Login with optional remember flag
  const login = async (email, password, remember = true) => {
    try {
      const response = await fetch(`${API_BASE_URL}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.detail || 'Login failed');
      }

      const data = await response.json();
      
      // Store token in localStorage or sessionStorage based on remember flag
      try {
        if (remember) {
          localStorage.setItem(TOKEN_KEY, data.access_token);
        } else {
          sessionStorage.setItem(TOKEN_KEY, data.access_token);
        }
      } catch (e) {
        console.warn('Storage not available, skipping token persistence', e);
      }

      setToken(data.access_token);
      
      // Set user
      setUser({
        id: data.user.id,
        tenantId: data.user.tenant_id,
        role: data.user.role,
        username: data.user.username,
        email: data.user.email,
        name: data.user.name,
      });

      return data;
    } catch (error) {
      console.error('Login error:', error);
      throw error;
    }
  };

  // Logout
  const logout = () => {
    localStorage.removeItem(TOKEN_KEY);
    setToken(null);
    setUser(null);
  };

  // Check role
  const hasRole = (...roles) => {
    return user && roles.includes(user.role);
  };

  const isMaster = () => hasRole(UserRole.MASTER);
  const isTenantAdmin = () => hasRole(UserRole.MASTER, UserRole.TENANT_ADMIN);
  const isTenantUser = () => hasRole(UserRole.TENANT_USER);

  // Get auth headers
  const getAuthHeaders = () => {
    if (!token) return {};
    return {
      'Authorization': `Bearer ${token}`,
    };
  };

  // Authenticated fetch wrapper
  const authFetch = async (url, options = {}) => {
    const headers = {
      ...options.headers,
      ...getAuthHeaders(),
    };

    const response = await fetch(url, { ...options, headers });

    // Handle 401 Unauthorized
    if (response.status === 401) {
      logout();
      throw new Error('Session expired. Please login again.');
    }

    return response;
  };

  const value = {
    user,
    token,
    loading,
    isAuthenticated: !!token,
    login,
    logout,
    hasRole,
    isMaster,
    isTenantAdmin,
    isTenantUser,
    getAuthHeaders,
    authFetch,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

// Hook to use auth context
export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};

// Protected route component
export const ProtectedRoute = ({ children, roles = [] }) => {
  const { user, loading } = useAuth();

  if (loading) {
    return <div className="loading">Loading...</div>;
  }

  if (!user) {
    return <div>Please login to access this page.</div>;
  }

  if (roles.length > 0 && !roles.includes(user.role)) {
    return (
      <div className="access-denied">
        <h2>Access Denied</h2>
        <p>You don't have permission to access this page.</p>
        <p>Required roles: {roles.join(', ')}</p>
      </div>
    );
  }

  return children;
};

// Master-only route
export const MasterRoute = ({ children }) => {
  return (
    <ProtectedRoute roles={[UserRole.MASTER]}>
      {children}
    </ProtectedRoute>
  );
};

// Admin route (Master or Tenant Admin)
export const AdminRoute = ({ children }) => {
  return (
    <ProtectedRoute roles={[UserRole.MASTER, UserRole.TENANT_ADMIN]}>
      {children}
    </ProtectedRoute>
  );
};
