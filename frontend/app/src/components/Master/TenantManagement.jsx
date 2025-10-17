/**
 * Tenant Management Component (MASTER only)
 * CRUD operations for tenants
 */
import React, { useState, useEffect } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import './TenantManagement.css';

const TenantManagement = () => {
  const { authFetch } = useAuth();
  const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3001';
  const [tenants, setTenants] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [editingTenant, setEditingTenant] = useState(null);

  // Form state
  const [formData, setFormData] = useState({
    name: '',
    slug: '',
    chatwoot_account_id: '',
    chatwoot_account_name: '',
    chatwoot_host: '',
  });

  // Load tenants
  useEffect(() => {
    loadTenants();
  }, []);

  const loadTenants = async () => {
    try {
      setLoading(true);
  const response = await authFetch(`${API_BASE_URL}/api/admin/tenants`);
      
      if (!response.ok) {
        throw new Error('Failed to load tenants');
      }

      const data = await response.json();
      setTenants(data);
      setError(null);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));

    // Auto-generate slug from name
    if (name === 'name' && !editingTenant) {
      const slug = value
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-|-$/g, '');
      setFormData(prev => ({ ...prev, slug }));
    }
  };

  const handleCreate = async (e) => {
    e.preventDefault();
    
    try {
  const response = await authFetch(`${API_BASE_URL}/api/admin/tenants`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: formData.name,
          slug: formData.slug,
          chatwoot_account_id: formData.chatwoot_account_id ? parseInt(formData.chatwoot_account_id) : null,
          chatwoot_account_name: formData.chatwoot_account_name || null,
          chatwoot_host: formData.chatwoot_host || null,
        }),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.detail || 'Failed to create tenant');
      }

      await loadTenants();
      setShowCreateModal(false);
      resetForm();
    } catch (err) {
      alert(`Error: ${err.message}`);
    }
  };

  const handleUpdate = async (e) => {
    e.preventDefault();
    
    try {
      const response = await authFetch(
  `${API_BASE_URL}/api/admin/tenants/${editingTenant.id}`,
        {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            name: formData.name,
            chatwoot_account_id: formData.chatwoot_account_id ? parseInt(formData.chatwoot_account_id) : null,
            chatwoot_account_name: formData.chatwoot_account_name || null,
            chatwoot_host: formData.chatwoot_host || null,
          }),
        }
      );

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.detail || 'Failed to update tenant');
      }

      await loadTenants();
      setEditingTenant(null);
      resetForm();
    } catch (err) {
      alert(`Error: ${err.message}`);
    }
  };

  const handleToggleActive = async (tenant) => {
    try {
      const response = await authFetch(
        `${API_BASE_URL}/api/admin/tenants/${tenant.id}`,
        {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            is_active: !tenant.is_active,
          }),
        }
      );

      if (!response.ok) {
        throw new Error('Failed to update tenant status');
      }

      await loadTenants();
    } catch (err) {
      alert(`Error: ${err.message}`);
    }
  };

  const startEdit = (tenant) => {
    setEditingTenant(tenant);
    setFormData({
      name: tenant.name,
      slug: tenant.slug,
      chatwoot_account_id: tenant.chatwoot_account_id || '',
      chatwoot_account_name: tenant.chatwoot_account_name || '',
      chatwoot_host: tenant.chatwoot_host || '',
    });
  };

  const resetForm = () => {
    setFormData({
      name: '',
      slug: '',
      chatwoot_account_id: '',
      chatwoot_account_name: '',
      chatwoot_host: '',
    });
  };

  if (loading) {
    return <div className="tenant-management loading">Loading tenants...</div>;
  }

  return (
    <div className="tenant-management">
      <div className="header">
        <h2>🏢 Tenant Management</h2>
        <button 
          className="btn btn-primary"
          onClick={() => setShowCreateModal(true)}
        >
          + Create Tenant
        </button>
      </div>

      {error && <div className="error-banner">{error}</div>}

      <div className="tenants-grid">
        {tenants.map(tenant => (
          <div 
            key={tenant.id} 
            className={`tenant-card ${!tenant.is_active ? 'inactive' : ''}`}
          >
            <div className="tenant-header">
              <h3>{tenant.name}</h3>
              <span className={`status-badge ${tenant.is_active ? 'active' : 'inactive'}`}>
                {tenant.is_active ? 'Active' : 'Inactive'}
              </span>
            </div>

            <div className="tenant-info">
              <p><strong>Slug:</strong> {tenant.slug}</p>
              <p><strong>Created:</strong> {new Date(tenant.created_at).toLocaleDateString()}</p>
            </div>

            <div className="tenant-metrics">
              <div className="metric">
                <span className="metric-value">{tenant.inbox_count}</span>
                <span className="metric-label">Inboxes</span>
              </div>
              <div className="metric">
                <span className="metric-value">{tenant.user_count}</span>
                <span className="metric-label">Users</span>
              </div>
              <div className="metric">
                <span className="metric-value">{tenant.conversation_count}</span>
                <span className="metric-label">Conversations</span>
              </div>
            </div>

            {tenant.chatwoot_account_id && (
              <div className="tenant-chatwoot">
                <p>🔗 Chatwoot: {tenant.chatwoot_account_name} (#{tenant.chatwoot_account_id})</p>
              </div>
            )}

            <div className="tenant-actions">
              <button 
                className="btn btn-secondary"
                onClick={() => startEdit(tenant)}
              >
                Edit
              </button>
              <button 
                className={`btn ${tenant.is_active ? 'btn-warning' : 'btn-success'}`}
                onClick={() => handleToggleActive(tenant)}
              >
                {tenant.is_active ? 'Deactivate' : 'Activate'}
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* Create Modal */}
      {showCreateModal && (
        <div className="modal-overlay" onClick={() => setShowCreateModal(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Create New Tenant</h3>
              <button className="close-btn" onClick={() => setShowCreateModal(false)}>×</button>
            </div>

            <form onSubmit={handleCreate}>
              <div className="form-group">
                <label>Name *</label>
                <input
                  type="text"
                  name="name"
                  value={formData.name}
                  onChange={handleInputChange}
                  required
                  placeholder="e.g., Acme Corporation"
                />
              </div>

              <div className="form-group">
                <label>Slug *</label>
                <input
                  type="text"
                  name="slug"
                  value={formData.slug}
                  onChange={handleInputChange}
                  required
                  pattern="^[a-z0-9-]+$"
                  placeholder="e.g., acme-corporation"
                />
                <small>URL-friendly identifier (lowercase, numbers, hyphens)</small>
              </div>

              <div className="form-group">
                <label>Chatwoot Account ID</label>
                <input
                  type="number"
                  name="chatwoot_account_id"
                  value={formData.chatwoot_account_id}
                  onChange={handleInputChange}
                  placeholder="e.g., 12345"
                />
              </div>

              <div className="form-group">
                <label>Chatwoot Account Name</label>
                <input
                  type="text"
                  name="chatwoot_account_name"
                  value={formData.chatwoot_account_name}
                  onChange={handleInputChange}
                  placeholder="e.g., Acme Chatwoot"
                />
              </div>

              <div className="form-group">
                <label>Chatwoot Host</label>
                <input
                  type="url"
                  name="chatwoot_host"
                  value={formData.chatwoot_host}
                  onChange={handleInputChange}
                  placeholder="e.g., https://app.chatwoot.com"
                />
              </div>

              <div className="modal-actions">
                <button type="button" className="btn btn-secondary" onClick={() => setShowCreateModal(false)}>
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary">
                  Create Tenant
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Edit Modal */}
      {editingTenant && (
        <div className="modal-overlay" onClick={() => setEditingTenant(null)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Edit Tenant: {editingTenant.name}</h3>
              <button className="close-btn" onClick={() => setEditingTenant(null)}>×</button>
            </div>

            <form onSubmit={handleUpdate}>
              <div className="form-group">
                <label>Name *</label>
                <input
                  type="text"
                  name="name"
                  value={formData.name}
                  onChange={handleInputChange}
                  required
                />
              </div>

              <div className="form-group">
                <label>Slug (read-only)</label>
                <input
                  type="text"
                  value={formData.slug}
                  disabled
                />
              </div>

              <div className="form-group">
                <label>Chatwoot Account ID</label>
                <input
                  type="number"
                  name="chatwoot_account_id"
                  value={formData.chatwoot_account_id}
                  onChange={handleInputChange}
                />
              </div>

              <div className="form-group">
                <label>Chatwoot Account Name</label>
                <input
                  type="text"
                  name="chatwoot_account_name"
                  value={formData.chatwoot_account_name}
                  onChange={handleInputChange}
                />
              </div>

              <div className="form-group">
                <label>Chatwoot Host</label>
                <input
                  type="url"
                  name="chatwoot_host"
                  value={formData.chatwoot_host}
                  onChange={handleInputChange}
                />
              </div>

              <div className="modal-actions">
                <button type="button" className="btn btn-secondary" onClick={() => setEditingTenant(null)}>
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary">
                  Save Changes
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default TenantManagement;
