/**
 * Manage Tenant Inboxes Modal
 * 
 * Allows MASTER to associate/dissociate multiple inboxes with a tenant
 */
import React, { useState, useEffect } from 'react';
import {
  listAllInboxes,
  getTenantInboxes,
  bulkAssociateInboxesToTenant,
} from '../../services/adminService';
import './ManageTenantInboxesModal.css';

const ManageTenantInboxesModal = ({ tenant, onClose }) => {
  const [allInboxes, setAllInboxes] = useState([]);
  const [selectedInboxIds, setSelectedInboxIds] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');

  // Load data
  useEffect(() => {
    loadData();
  }, [tenant.id]);

  const loadData = async () => {
    setLoading(true);
    setError(null);

    try {
      // Load all inboxes
      const [inboxes, tenantInboxes] = await Promise.all([
        listAllInboxes({ isActive: true }),
        getTenantInboxes(tenant.id),
      ]);

      setAllInboxes(inboxes);
      
      // Set selected inboxes
      const selected = tenantInboxes.map(inbox => inbox.id);
      setSelectedInboxIds(selected);
    } catch (err) {
      console.error('Error loading inboxes:', err);
      setError(err.message || 'Erro ao carregar inboxes');
    } finally {
      setLoading(false);
    }
  };

  // Toggle inbox selection
  const toggleInbox = (inboxId) => {
    setSelectedInboxIds(prev => {
      if (prev.includes(inboxId)) {
        return prev.filter(id => id !== inboxId);
      } else {
        return [...prev, inboxId];
      }
    });
  };

  // Select all filtered inboxes
  const selectAll = () => {
    const filtered = getFilteredInboxes();
    const filteredIds = filtered.map(inbox => inbox.id);
    setSelectedInboxIds(prev => {
      // Add all filtered that are not already selected
      const newIds = filteredIds.filter(id => !prev.includes(id));
      return [...prev, ...newIds];
    });
  };

  // Deselect all filtered inboxes
  const deselectAll = () => {
    const filtered = getFilteredInboxes();
    const filteredIds = filtered.map(inbox => inbox.id);
    setSelectedInboxIds(prev => prev.filter(id => !filteredIds.includes(id)));
  };

  // Get filtered inboxes
  const getFilteredInboxes = () => {
    if (!searchTerm) return allInboxes;
    
    const term = searchTerm.toLowerCase();
    return allInboxes.filter(inbox =>
      inbox.name.toLowerCase().includes(term) ||
      inbox.channel_type.toLowerCase().includes(term) ||
      (inbox.tenant_name && inbox.tenant_name.toLowerCase().includes(term))
    );
  };

  // Save associations
  const handleSave = async () => {
    setSaving(true);
    setError(null);

    try {
      await bulkAssociateInboxesToTenant(tenant.id, selectedInboxIds);
      
      // Success - close modal
      onClose();
    } catch (err) {
      console.error('Error saving inbox associations:', err);
      setError(err.message || 'Erro ao salvar associações');
    } finally {
      setSaving(false);
    }
  };

  const filteredInboxes = getFilteredInboxes();
  const selectedCount = selectedInboxIds.length;

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content manage-inboxes-modal" onClick={(e) => e.stopPropagation()}>
        {/* Header */}
        <div className="modal-header">
          <div>
            <h2>Gerenciar Inboxes</h2>
            <p className="modal-subtitle">
              Tenant: <strong>{tenant.name}</strong> ({tenant.slug})
            </p>
          </div>
          <button
            type="button"
            className="btn-close"
            onClick={onClose}
            disabled={saving}
          >
            ✕
          </button>
        </div>

        {/* Error */}
        {error && (
          <div className="modal-error">
            <span>⚠️ {error}</span>
            <button onClick={loadData}>Tentar novamente</button>
          </div>
        )}

        {/* Loading */}
        {loading ? (
          <div className="modal-loading">
            <div className="spinner"></div>
            <span>Carregando inboxes...</span>
          </div>
        ) : (
          <>
            {/* Search & Bulk Actions */}
            <div className="inbox-filters">
              <input
                type="text"
                placeholder="Buscar inbox..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="search-input"
              />
              
              <div className="bulk-actions">
                <button
                  type="button"
                  className="btn-link"
                  onClick={selectAll}
                  disabled={saving}
                >
                  Selecionar todos
                </button>
                <span>|</span>
                <button
                  type="button"
                  className="btn-link"
                  onClick={deselectAll}
                  disabled={saving}
                >
                  Desmarcar todos
                </button>
              </div>
            </div>

            {/* Selected Count */}
            <div className="selection-info">
              <span className="count-badge">{selectedCount}</span>
              <span> inbox{selectedCount !== 1 ? 'es' : ''} selecionado{selectedCount !== 1 ? 's' : ''}</span>
            </div>

            {/* Inbox List */}
            <div className="inbox-list">
              {filteredInboxes.length === 0 ? (
                <div className="no-inboxes">
                  {searchTerm ? 'Nenhum inbox encontrado' : 'Nenhum inbox disponível'}
                </div>
              ) : (
                filteredInboxes.map((inbox) => {
                  const isSelected = selectedInboxIds.includes(inbox.id);
                  
                  return (
                    <label
                      key={inbox.id}
                      className={`inbox-item ${isSelected ? 'selected' : ''}`}
                    >
                      <input
                        type="checkbox"
                        checked={isSelected}
                        onChange={() => toggleInbox(inbox.id)}
                        disabled={saving}
                      />
                      
                      <div className="inbox-info">
                        <div className="inbox-name">{inbox.name}</div>
                        <div className="inbox-meta">
                          <span className="inbox-channel">{inbox.channel_type}</span>
                          {inbox.tenant_name && (
                            <>
                              <span className="separator">•</span>
                              <span className="inbox-tenant">{inbox.tenant_name}</span>
                            </>
                          )}
                          {inbox.conversation_count > 0 && (
                            <>
                              <span className="separator">•</span>
                              <span className="inbox-conversations">
                                {inbox.conversation_count} conversas
                              </span>
                            </>
                          )}
                        </div>
                      </div>
                      
                      <div className="checkbox-indicator">
                        {isSelected && <span>✓</span>}
                      </div>
                    </label>
                  );
                })
              )}
            </div>
          </>
        )}

        {/* Actions */}
        <div className="modal-actions">
          <button
            type="button"
            className="btn btn-secondary"
            onClick={onClose}
            disabled={saving}
          >
            Cancelar
          </button>
          <button
            type="button"
            className="btn btn-primary"
            onClick={handleSave}
            disabled={loading || saving}
          >
            {saving ? 'Salvando...' : 'Salvar Associações'}
          </button>
        </div>
      </div>
    </div>
  );
};

export default ManageTenantInboxesModal;
