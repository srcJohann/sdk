/**
 * Tenant Inboxes View - For TENANT_ADMIN role
 * View inboxes associated with their tenant
 */
import React, { useState, useEffect } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import adminService from '../../services/adminService';
import './TenantInboxesView.css';

const TenantInboxesView = () => {
  const { user } = useAuth();
  const [inboxes, setInboxes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadInboxes();
  }, []);

  const loadInboxes = async () => {
    try {
      setLoading(true);
      const data = await adminService.getTenantInboxes(user.tenant_id);
      setInboxes(data);
    } catch (err) {
      console.error('Error loading inboxes:', err);
      setError(err.message || 'Erro ao carregar inboxes');
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <div className="view-loading">Carregando inboxes...</div>;

  return (
    <div className="tenant-inboxes-view">
      <div className="view-header">
        <h1>Inboxes do Tenant</h1>
      </div>

      {error && <div className="alert alert-error">⚠️ {error}</div>}

      <div className="inboxes-grid">
        {inboxes.map(inbox => (
          <div key={inbox.id} className="inbox-card">
            <div className="inbox-header">
              <h3>{inbox.name}</h3>
              <span className={`status-badge ${inbox.is_active ? 'active' : 'inactive'}`}>
                {inbox.is_active ? '✓ Ativo' : '✗ Inativo'}
              </span>
            </div>
            <div className="inbox-info">
              <p><strong>Tipo:</strong> {inbox.type || 'N/A'}</p>
              <p><strong>Chatwoot ID:</strong> {inbox.chatwoot_inbox_id || 'N/A'}</p>
            </div>
          </div>
        ))}
      </div>

      {inboxes.length === 0 && (
        <div className="empty-state">
          <p>📥 Nenhum inbox associado a este tenant</p>
        </div>
      )}
    </div>
  );
};

export default TenantInboxesView;
