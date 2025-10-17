// ============================================================================
// DOM360 Frontend - API Service
// Integration with Backend API (PostgreSQL + Agent)
// ============================================================================

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3001';
// Key used by AuthContext to store JWT
const TOKEN_KEY = 'dom360_auth_token';

/**
 * API Service for DOM360 Backend
 */
class DOM360ApiService {
    constructor() {
        this.baseUrl = API_BASE_URL;
        this.tenantId = null;
        this.inboxId = null;
    }

    /**
     * Initialize with tenant and inbox
     */
    initialize(tenantId, inboxId) {
        this.tenantId = tenantId;
        this.inboxId = inboxId;
    }

    /**
     * Generic fetch wrapper with error handling
     */
    async fetch(endpoint, options = {}) {
        const url = `${this.baseUrl}${endpoint}`;
        
        const defaultHeaders = {
            'Content-Type': 'application/json',
        };

        // ALWAYS try to get JWT token from localStorage or sessionStorage
        // This ensures authentication is sent with every request
        try {
            const token = localStorage.getItem(TOKEN_KEY) || sessionStorage.getItem(TOKEN_KEY);
            if (token) {
                defaultHeaders['Authorization'] = `Bearer ${token}`;
            } else {
                // Warn if no token available for authenticated endpoints
                if (!endpoint.includes('/health') && !endpoint.includes('/login')) {
                    console.warn(`[API Service] No JWT token found for ${endpoint}. Request may fail with 401/403.`);
                }
            }
        } catch (e) {
            // localStorage/sessionStorage might not be available in some environments (SSR/tests)
            console.debug('Storage not available:', e);
        }

        // Add tenant and inbox headers if initialized
        if (this.tenantId) {
            defaultHeaders['X-Tenant-ID'] = this.tenantId;
        }
        if (this.inboxId) {
            defaultHeaders['X-Inbox-ID'] = this.inboxId;
        }

        const config = {
            ...options,
            headers: {
                ...defaultHeaders,
                ...options.headers,
            },
        };

        try {
            const response = await fetch(url, config);
            
            // Handle 401/403 errors before parsing JSON
            if (response.status === 401) {
                const errorData = await response.json().catch(() => ({ detail: 'Unauthorized' }));
                console.error(`[API Service] 401 Unauthorized on ${endpoint}:`, errorData.detail);
                throw new Error(`Authentication required: ${errorData.detail || 'Please login again'}`);
            }
            
            if (response.status === 403) {
                const errorData = await response.json().catch(() => ({ detail: 'Forbidden' }));
                console.error(`[API Service] 403 Forbidden on ${endpoint}:`, errorData.detail);
                throw new Error(`Access denied: ${errorData.detail || 'Insufficient permissions'}`);
            }
            
            const data = await response.json();

            if (!response.ok) {
                throw new Error(data.detail || data.error || `HTTP ${response.status}`);
            }

            return data;
        } catch (error) {
            console.error(`API Error [${endpoint}]:`, error);
            throw error;
        }
    }

    /**
     * Health check
     */
    async healthCheck() {
        return this.fetch('/api/health');
    }

    /**
     * Send message to agent
     */
    async sendMessage(message, conversationId = null, agentType = 'SDR', userPhone = '+5511999999999', userName = 'Usuário') {
        if (!this.tenantId || !this.inboxId) {
            throw new Error('API not initialized. Call initialize() first.');
        }

        return this.fetch('/api/chat', {
            method: 'POST',
            body: JSON.stringify({
                message: message,
                conversation_id: conversationId,
                agent_type: agentType,
                user_phone: userPhone,
                user_name: userName,
            }),
        });
    }

    /**
     * Get conversation messages
     */
    async getConversationMessages(conversationId) {
        if (!this.tenantId) {
            throw new Error('API not initialized. Call initialize() first.');
        }

        return this.fetch(`/api/conversations/${conversationId}/messages`);
    }

    /**
     * List all conversations
     */
    async listConversations(limit = 50) {
        if (!this.tenantId || !this.inboxId) {
            throw new Error('API not initialized. Call initialize() first.');
        }

        return this.fetch(`/api/conversations?limit=${limit}`);
    }

    /**
     * Get consumption dashboard data
     */
    async getConsumptionDashboard(days = 30) {
        if (!this.tenantId || !this.inboxId) {
            throw new Error('API not initialized. Call initialize() first.');
        }

        return this.fetch(`/api/dashboard/consumption?days=${days}`);
    }
}

// Export singleton instance
export const apiService = new DOM360ApiService();

export default apiService;
