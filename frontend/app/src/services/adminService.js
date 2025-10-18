/**
 * Admin Service - Master Management API
 * 
 * Provides functions for MASTER users to manage:
 * - Tenants
 * - Inbox associations
 * - Master settings (SDR endpoint)
 * - Global metrics
 */

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3001';

/**
 * Get auth headers with token
 */
const getAuthHeaders = () => {
  const token = localStorage.getItem('dom360_auth_token') || sessionStorage.getItem('dom360_auth_token');
  return {
    'Content-Type': 'application/json',
    ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
  };
};

/**
 * Handle API response
 */
/**
 * Handle API response
 */
const handleResponse = async (response) => {
  console.log('[adminService.handleResponse] Called with response:', {
    status: response.status,
    statusText: response.statusText,
    ok: response.ok,
    url: response.url
  });

  if (!response.ok) {
    let errorMessage = `HTTP Error ${response.status}`;
    
    try {
      // Try to parse response as JSON
      const errorData = await response.json();
      console.log('[adminService.handleResponse] Error response JSON:', errorData);
      
      // Try multiple ways to extract the error message
      if (typeof errorData === 'string') {
        errorMessage = errorData;
      } else if (errorData.detail) {
        errorMessage = typeof errorData.detail === 'string' 
          ? errorData.detail 
          : JSON.stringify(errorData.detail);
      } else if (errorData.message) {
        errorMessage = errorData.message;
      } else if (errorData.error) {
        errorMessage = errorData.error;
      } else {
        errorMessage = JSON.stringify(errorData);
      }
    } catch (parseError) {
      console.log('[adminService.handleResponse] Failed to parse error JSON:', parseError);
      // If JSON parsing fails, try to get the response as text
      try {
        errorMessage = await response.text();
        console.log('[adminService.handleResponse] Error as text:', errorMessage);
      } catch (textError) {
        console.log('[adminService.handleResponse] Failed to get text:', textError);
        errorMessage = `HTTP Error ${response.status}: ${response.statusText}`;
      }
    }
    
    console.log('[adminService.handleResponse] Final error message:', errorMessage);
    throw new Error(errorMessage);
  }

  const data = await response.json();
  console.log('[adminService.handleResponse] Success data:', data);
  return data;
};

// ============================================================================
// Tenant Management
// ============================================================================

/**
 * List all tenants
 */
export const listTenants = async ({ is_active, limit = 100, offset = 0 } = {}) => {
  const params = new URLSearchParams();
  
  // Only add is_active if it has a valid value
  if (is_active !== undefined && is_active !== null && is_active !== '') {
    params.append('is_active', is_active);
  }
  params.append('limit', limit);
  params.append('offset', offset);

  console.log('[adminService.listTenants] Fetching:', `${API_BASE_URL}/api/admin/tenants?${params}`);

  const response = await fetch(
    `${API_BASE_URL}/api/admin/tenants?${params}`,
    {
      method: 'GET',
      headers: getAuthHeaders(),
    }
  );

  console.log('[adminService.listTenants] Response status:', response.status);
  console.log('[adminService.listTenants] Response ok:', response.ok);

  return handleResponse(response);
};

/**
 * Get tenant details
 */
export const getTenant = async (tenantId) => {
  const response = await fetch(
    `${API_BASE_URL}/api/admin/tenants/${tenantId}`,
    {
      method: 'GET',
      headers: getAuthHeaders(),
    }
  );

  return handleResponse(response);
};

/**
 * Create new tenant
 */
export const createTenant = async ({ name, slug, chatwootAccountId, chatwootAccountName, chatwootHost }) => {
  const response = await fetch(
    `${API_BASE_URL}/api/admin/tenants`,
    {
      method: 'POST',
      headers: getAuthHeaders(),
      body: JSON.stringify({
        name,
        slug,
        chatwoot_account_id: chatwootAccountId,
        chatwoot_account_name: chatwootAccountName,
        chatwoot_host: chatwootHost,
      }),
    }
  );

  return handleResponse(response);
};

/**
 * Update tenant
 */
export const updateTenant = async (tenantId, { name, isActive, chatwootAccountId, chatwootAccountName, chatwootHost }) => {
  const updates = {};
  if (name !== undefined) updates.name = name;
  if (isActive !== undefined) updates.is_active = isActive;
  if (chatwootAccountId !== undefined) updates.chatwoot_account_id = chatwootAccountId;
  if (chatwootAccountName !== undefined) updates.chatwoot_account_name = chatwootAccountName;
  if (chatwootHost !== undefined) updates.chatwoot_host = chatwootHost;

  const response = await fetch(
    `${API_BASE_URL}/api/admin/tenants/${tenantId}`,
    {
      method: 'PUT',
      headers: getAuthHeaders(),
      body: JSON.stringify(updates),
    }
  );

  return handleResponse(response);
};

/**
 * Delete tenant
 */
export const deleteTenant = async (tenantId) => {
  const response = await fetch(
    `${API_BASE_URL}/api/admin/tenants/${tenantId}`,
    {
      method: 'DELETE',
      headers: getAuthHeaders(),
    }
  );

  return handleResponse(response);
};

// ============================================================================
// Inbox Management
// ============================================================================

/**
 * List all inboxes (Master sees all, Tenant Admin sees their tenant's inboxes)
 */
export const listAllInboxes = async ({ tenant_id, is_active, limit = 100, offset = 0 } = {}) => {
  const params = new URLSearchParams();
  
  // Only add parameters if they have valid values
  if (tenant_id && tenant_id !== '') params.append('tenant_id', tenant_id);
  if (is_active !== undefined && is_active !== null && is_active !== '') {
    params.append('is_active', is_active);
  }
  params.append('limit', limit);
  params.append('offset', offset);

  console.log('[adminService.listAllInboxes] Fetching:', `${API_BASE_URL}/api/admin/inboxes?${params}`);

  const response = await fetch(
    `${API_BASE_URL}/api/admin/inboxes?${params}`,
    {
      method: 'GET',
      headers: getAuthHeaders(),
    }
  );

  console.log('[adminService.listAllInboxes] Response status:', response.status);
  console.log('[adminService.listAllInboxes] Response ok:', response.ok);

  return handleResponse(response);
};

/**
 * Create new inbox
 */
export const createInbox = async ({ tenant_id, name, external_id, agent_type, is_active = true }) => {
  const response = await fetch(
    `${API_BASE_URL}/api/admin/inboxes`,
    {
      method: 'POST',
      headers: getAuthHeaders(),
      body: JSON.stringify({
        tenant_id,
        name,
        external_id,
        agent_type: agent_type || 'SDR',
        is_active
      }),
    }
  );

  return handleResponse(response);
};

/**
 * Update inbox
 */
export const updateInbox = async (inboxId, { name, external_id, agent_type, is_active }) => {
  const updates = {};
  if (name !== undefined) updates.name = name;
  if (external_id !== undefined) updates.external_id = external_id;
  if (agent_type !== undefined) updates.agent_type = agent_type;
  if (is_active !== undefined) updates.is_active = is_active;

  const response = await fetch(
    `${API_BASE_URL}/api/admin/inboxes/${inboxId}`,
    {
      method: 'PUT',
      headers: getAuthHeaders(),
      body: JSON.stringify(updates),
    }
  );

  return handleResponse(response);
};

/**
 * Delete inbox
 */
export const deleteInbox = async (inboxId) => {
  const response = await fetch(
    `${API_BASE_URL}/api/admin/inboxes/${inboxId}`,
    {
      method: 'DELETE',
      headers: getAuthHeaders(),
    }
  );

  return handleResponse(response);
};

/**
 * Get inboxes associated with a tenant
 */
export const getTenantInboxes = async (tenantId) => {
  const response = await fetch(
    `${API_BASE_URL}/api/admin/tenants/${tenantId}/inboxes`,
    {
      method: 'GET',
      headers: getAuthHeaders(),
    }
  );

  return handleResponse(response);
};

/**
 * Associate single inbox to tenant
 */
export const associateInboxToTenant = async (tenantId, inboxId) => {
  const response = await fetch(
    `${API_BASE_URL}/api/admin/tenants/${tenantId}/inboxes`,
    {
      method: 'POST',
      headers: getAuthHeaders(),
      body: JSON.stringify({ inbox_id: inboxId }),
    }
  );

  return handleResponse(response);
};

/**
 * Associate multiple inboxes to tenant (replaces all associations)
 */
export const bulkAssociateInboxesToTenant = async (tenantId, inboxIds) => {
  const response = await fetch(
    `${API_BASE_URL}/api/admin/tenants/${tenantId}/inboxes/bulk`,
    {
      method: 'POST',
      headers: getAuthHeaders(),
      body: JSON.stringify({ inbox_ids: inboxIds }),
    }
  );

  return handleResponse(response);
};

/**
 * Dissociate inbox from tenant
 */
export const dissociateInboxFromTenant = async (tenantId, inboxId) => {
  const response = await fetch(
    `${API_BASE_URL}/api/admin/tenants/${tenantId}/inboxes/${inboxId}`,
    {
      method: 'DELETE',
      headers: getAuthHeaders(),
    }
  );

  return handleResponse(response);
};

// ============================================================================
// Master Settings
// ============================================================================

/**
 * Get master settings (SDR endpoint, server config)
 */
export const getMasterSettings = async () => {
  const response = await fetch(
    `${API_BASE_URL}/api/admin/master-settings`,
    {
      method: 'GET',
      headers: getAuthHeaders(),
    }
  );

  return handleResponse(response);
};

/**
 * Update master settings
 */
export const updateMasterSettings = async ({
  sdrAgentEndpoint,
  sdrAgentApiKey,
  sdrAgentTimeoutMs,
  serverConfig,
  healthCheckEnabled,
  healthCheckIntervalSeconds,
}) => {
  const updates = {};
  if (sdrAgentEndpoint !== undefined) updates.sdr_agent_endpoint = sdrAgentEndpoint;
  if (sdrAgentApiKey !== undefined) updates.sdr_agent_api_key = sdrAgentApiKey;
  if (sdrAgentTimeoutMs !== undefined) updates.sdr_agent_timeout_ms = sdrAgentTimeoutMs;
  if (serverConfig !== undefined) updates.server_config = serverConfig;
  if (healthCheckEnabled !== undefined) updates.health_check_enabled = healthCheckEnabled;
  if (healthCheckIntervalSeconds !== undefined) updates.health_check_interval_seconds = healthCheckIntervalSeconds;

  const response = await fetch(
    `${API_BASE_URL}/api/admin/master-settings`,
    {
      method: 'PUT',
      headers: getAuthHeaders(),
      body: JSON.stringify(updates),
    }
  );

  return handleResponse(response);
};

/**
 * Test SDR agent health check
 */
export const testSdrHealthCheck = async () => {
  const response = await fetch(
    `${API_BASE_URL}/api/admin/master-settings/health-check`,
    {
      method: 'POST',
      headers: getAuthHeaders(),
    }
  );

  return handleResponse(response);
};

// ============================================================================
// User Management
// ============================================================================

/**
 * List all users (Master can see all, Tenant Admin sees their tenant)
 */
export const listUsers = async ({ tenant_id, role, is_active, limit = 100, offset = 0 } = {}) => {
  const params = new URLSearchParams();
  
  // Only add parameters if they have valid values
  if (tenant_id && tenant_id !== '') params.append('tenant_id', tenant_id);
  if (role && role !== '') params.append('role', role);
  if (is_active !== undefined && is_active !== null && is_active !== '') {
    params.append('is_active', is_active);
  }
  params.append('limit', limit);
  params.append('offset', offset);

  console.log('[adminService.listUsers] Fetching:', `${API_BASE_URL}/api/auth/users?${params}`);

  const response = await fetch(
    `${API_BASE_URL}/api/auth/users?${params}`,
    {
      method: 'GET',
      headers: getAuthHeaders(),
    }
  );

  console.log('[adminService.listUsers] Response status:', response.status);
  console.log('[adminService.listUsers] Response ok:', response.ok);

  return handleResponse(response);
};

/**
 * Get user by ID
 */
export const getUser = async (userId) => {
  const response = await fetch(
    `${API_BASE_URL}/api/auth/users/${userId}`,
    {
      method: 'GET',
      headers: getAuthHeaders(),
    }
  );

  return handleResponse(response);
};

/**
 * Create new user
 * Master can create users in any tenant with any role
 */
export const createUser = async ({ name, username, email, password, tenant_id, role, is_active, inbox_ids }) => {
  const response = await fetch(
    `${API_BASE_URL}/api/auth/users`,
    {
      method: 'POST',
      headers: getAuthHeaders(),
      body: JSON.stringify({
        name,
        username,
        email,
        password,
        tenant_id,
        role,
        is_active: is_active !== undefined ? is_active : true,
        inbox_ids, // Optional array of inbox IDs
      }),
    }
  );

  return handleResponse(response);
};

/**
 * Update user
 */
export const updateUser = async (userId, { name, username, email, role, tenant_id, is_active }) => {
  const updates = {};
  if (name !== undefined) updates.name = name;
  if (username !== undefined) updates.username = username;
  if (email !== undefined) updates.email = email;
  if (role !== undefined) updates.role = role;
  if (tenant_id !== undefined) updates.tenant_id = tenant_id;
  if (is_active !== undefined) updates.is_active = is_active;

  const response = await fetch(
    `${API_BASE_URL}/api/auth/users/${userId}`,
    {
      method: 'PUT',
      headers: getAuthHeaders(),
      body: JSON.stringify(updates),
    }
  );

  return handleResponse(response);
};

/**
 * Delete user (soft delete - sets is_active = false)
 */
export const deleteUser = async (userId) => {
  const response = await fetch(
    `${API_BASE_URL}/api/auth/users/${userId}`,
    {
      method: 'DELETE',
      headers: getAuthHeaders(),
    }
  );

  return handleResponse(response);
};

// ============================================================================
// Global Metrics
// ============================================================================

/**
 * Get global metrics for Master dashboard
 */
export const getGlobalMetrics = async ({ fromDate, toDate } = {}) => {
  const params = new URLSearchParams();
  if (fromDate) params.append('from_date', fromDate);
  if (toDate) params.append('to_date', toDate);

  const response = await fetch(
    `${API_BASE_URL}/api/admin/metrics?${params}`,
    {
      method: 'GET',
      headers: getAuthHeaders(),
    }
  );

  return handleResponse(response);
};

// Export default object
export default {
  // Tenants
  getTenants: listTenants,
  listTenants,
  getTenant,
  createTenant,
  updateTenant,
  
  // Inboxes
  getInboxes: listAllInboxes,
  listAllInboxes,
  createInbox,
  updateInbox,
  deleteInbox,
  getTenantInboxes,
  associateInboxToTenant,
  bulkAssociateInboxesToTenant,
  dissociateInboxFromTenant,
  
  // Users
  getUsers: listUsers,
  listUsers,
  getUser,
  createUser,
  updateUser,
  deleteUser,
  
  // Settings
  getMasterSettings,
  updateMasterSettings,
  testSdrHealthCheck,
  
  // Metrics
  getGlobalMetrics,
};
