/**
 * Tenants List Component
 * 
 * Displays list of tenants with search, filtering, and pagination
 * Allows creating new tenants and managing existing ones
 */
import React, { useState, useEffect } from 'react';
import { listTenants } from '../../services/adminService';
import CreateTenantForm from './CreateTenantForm';
import ManageTenantInboxesModal from './ManageTenantInboxesModal';
import './TenantsList.css';

const TenantsList = () => {
  const [tenants, setTenants] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  // Filters
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('all'); // all, active, inactive
  
  // Pagination
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize] = useState(20);
  const [totalTenants, setTotalTenants] = useState(0);
  
  // Modal states
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [selectedTenant, setSelectedTenant] = useState(null);
  const [showInboxesModal, setShowInboxesModal] = useState(false);

  // Load tenants
  const loadTenants = async () => {
    setLoading(true);
    setError(null);
    
    try {
      const isActiveFilter = statusFilter === 'all' ? undefined : statusFilter === 'active';
      const offset = (currentPage - 1) * pageSize;
      
      const data = await listTenants({
        isActive: isActiveFilter,
        limit: pageSize,
        offset,
      });
      
      setTenants(data);
      setTotalTenants(data.length); // Note: backend should return total count
    } catch (err) {
      console.error('Error loading tenants:', err);
      setError(err.message || 'Erro ao carregar tenants');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadTenants();
  }, [currentPage, statusFilter]);

  // Filter tenants by search term (client-side)
  const filteredTenants = tenants.filter(tenant =>
    tenant.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    tenant.slug.toLowerCase().includes(searchTerm.toLowerCase())
  );

  // Pagination
  const totalPages = Math.ceil(totalTenants / pageSize);

  // Handle tenant creation success
  const handleTenantCreated = (newTenant) => {
    setShowCreateForm(false);
    loadTenants(); // Reload list
  };

  // Handle manage inboxes
  const handleManageInboxes = (tenant) => {
    setSelectedTenant(tenant);
    setShowInboxesModal(true);
  };

  // Handle status toggle
  const handleToggleStatus = async (tenant) => {
    try {
      const { updateTenant } = await import('../../services/adminService');
      await updateTenant(tenant.id, { isActive: !tenant.is_active });
      loadTenants();
    } catch (err) {
      alert(`Erro ao atualizar status: ${err.message}`);
    }
  };

  // Format date
  const formatDate = (dateString) => {
    if (!dateString) return '-';
    const date = new Date(dateString);
    return date.toLocaleDateString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
    });
  };

  return (
    <div className="tenants-list">
      <div className="tenants-list-header">
        <h1>Gerenciar Tenants</h1>
        <button 
          className="btn btn-primary"
          onClick={() => setShowCreateForm(true)}
        >
          + Criar Tenant
        </button>
      </div>

      {/* Filters */}
      <div className="tenants-filters">
        <input
          type="text"
          placeholder="Buscar por nome ou slug..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="search-input"
        />
        
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="status-filter"
        >
          <option value="all">Todos</option>
          <option value="active">Ativos</option>
          <option value="inactive">Inativos</option>
        </select>
      </div>

      {/* Error */}
      {error && (
        <div className="error-message">
          <span>⚠️ {error}</span>
          <button onClick={loadTenants}>Tentar novamente</button>
        </div>
      )}

      {/* Loading */}
      {loading && (
        <div className="loading-spinner">
          <div className="spinner"></div>
          <span>Carregando tenants...</span>
        </div>
      )}

      {/* Table */}
      {!loading && !error && (
        <>
          <div className="tenants-table-container">
            <table className="tenants-table">
              <thead>
                <tr>
                  <th>Nome</th>
                  <th>Slug</th>
                  <th>Status</th>
                  <th>Inboxes</th>
                  <th>Usuários</th>
                  <th>Conversas</th>
                  <th>Criado em</th>
                  <th>Ações</th>
                </tr>
              </thead>
              <tbody>
                {filteredTenants.length === 0 ? (
                  <tr>
                    <td colSpan="8" className="no-data">
                      Nenhum tenant encontrado
                    </td>
                  </tr>
                ) : (
                  filteredTenants.map((tenant) => (
                    <tr key={tenant.id}>
                      <td>
                        <strong>{tenant.name}</strong>
                      </td>
                      <td>
                        <code>{tenant.slug}</code>
                      </td>
                      <td>
                        <span className={`status-badge ${tenant.is_active ? 'active' : 'inactive'}`}>
                          {tenant.is_active ? 'Ativo' : 'Inativo'}
                        </span>
                      </td>
                      <td className="metric-cell">{tenant.inbox_count || 0}</td>
                      <td className="metric-cell">{tenant.user_count || 0}</td>
                      <td className="metric-cell">{tenant.conversation_count || 0}</td>
                      <td>{formatDate(tenant.created_at)}</td>
                      <td className="actions-cell">
                        <button
                          className="btn-icon"
                          onClick={() => handleManageInboxes(tenant)}
                          title="Gerenciar Inboxes"
                        >
                          📥
                        </button>
                        <button
                          className="btn-icon"
                          onClick={() => handleToggleStatus(tenant)}
                          title={tenant.is_active ? 'Desativar' : 'Ativar'}
                        >
                          {tenant.is_active ? '🔴' : '🟢'}
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="pagination">
              <button
                onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                disabled={currentPage === 1}
                className="btn btn-secondary"
              >
                ← Anterior
              </button>
              
              <span className="page-info">
                Página {currentPage} de {totalPages}
              </span>
              
              <button
                onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                disabled={currentPage === totalPages}
                className="btn btn-secondary"
              >
                Próxima →
              </button>
            </div>
          )}
        </>
      )}

      {/* Create Tenant Modal */}
      {showCreateForm && (
        <div className="modal-overlay" onClick={() => setShowCreateForm(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <CreateTenantForm
              onSuccess={handleTenantCreated}
              onCancel={() => setShowCreateForm(false)}
            />
          </div>
        </div>
      )}

      {/* Manage Inboxes Modal */}
      {showInboxesModal && selectedTenant && (
        <ManageTenantInboxesModal
          tenant={selectedTenant}
          onClose={() => {
            setShowInboxesModal(false);
            setSelectedTenant(null);
            loadTenants(); // Reload to refresh inbox counts
          }}
        />
      )}
    </div>
  );
};

export default TenantsList;
