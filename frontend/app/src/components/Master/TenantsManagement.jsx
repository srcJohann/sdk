/**
 * Tenants Management - Master Admin
 * Full CRUD for tenant management
 */
import React, { useState, useEffect } from 'react';
import { Building2, Edit, Trash2, X } from 'lucide-react';
import adminService from '../../services/adminService';
import './TenantsManagement.css';

const TenantsManagement = () => {
  const [tenants, setTenants] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [showForm, setShowForm] = useState(false);
  const [editingTenant, setEditingTenant] = useState(null);
  const [formData, setFormData] = useState({
    name: '',
    chatwoot_account_id: '',
    chatwoot_account_name: '',
    chatwoot_host: '',
    is_active: true
  });

  useEffect(() => {
    loadTenants();
  }, []);

  const loadTenants = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await adminService.listTenants();
      setTenants(data);
    } catch (err) {
      console.error('Error loading tenants:', err);
      setError(err.message || 'Erro ao carregar tenants');
    } finally {
      setLoading(false);
    }
  };

  const resetForm = () => {
    setFormData({
      name: '',
      chatwoot_account_id: '',
      chatwoot_account_name: '',
      chatwoot_host: '',
      is_active: true
    });
    setEditingTenant(null);
    setShowForm(false);
  };

  const handleEdit = (tenant) => {
    setEditingTenant(tenant);
    setFormData({
      name: tenant.name,
      chatwoot_account_id: tenant.chatwoot_account_id || '',
      chatwoot_account_name: tenant.chatwoot_account_name || '',
      chatwoot_host: tenant.chatwoot_host || '',
      is_active: tenant.is_active
    });
    setShowForm(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);

    try {
      // Prepare data
      const data = {
        name: formData.name.trim(),
        // slug removed: backend will use chatwoot_account_id as identifier
        slug: null,
        chatwootAccountId: formData.chatwoot_account_id ? parseInt(formData.chatwoot_account_id) : null,
        chatwootAccountName: formData.chatwoot_account_name.trim() || null,
        chatwootHost: formData.chatwoot_host.trim() || null,
        isActive: formData.is_active
      };

      if (editingTenant) {
        // Update
        await adminService.updateTenant(editingTenant.id, data);
        alert('Tenant atualizado com sucesso!');
      } else {
        // Create
        await adminService.createTenant(data);
        alert('Tenant criado com sucesso!');
      }

      resetForm();
      loadTenants();
    } catch (err) {
      console.error('Error saving tenant:', err);
      setError(err.message || 'Erro ao salvar tenant');
    }
  };

  const handleDelete = async (tenantId, tenantName) => {
    if (!confirm(`Tem certeza que deseja excluir o tenant "${tenantName}"?\n\nATENÇÃO: Esta ação não pode ser desfeita e todos os dados relacionados serão perdidos!`)) {
      return;
    }

    try {
      setError(null);
      await adminService.deleteTenant(tenantId);
      alert('Tenant excluído com sucesso!');
      loadTenants();
    } catch (err) {
      console.error('Error deleting tenant:', err);
      setError(err.message || 'Erro ao excluir tenant');
    }
  };

  if (loading) {
    return <div className="loading">Carregando tenants...</div>;
  }

  return (
    <div className="page-container">
      <div className="page-header">
        <h1 className="page-title">
          <Building2 size={24} />
          Gerenciamento de Tenants
        </h1>
        <button 
          className="btn-filter"
          onClick={() => {
            if (showForm) {
              resetForm();
            } else {
              setShowForm(true);
            }
          }}
        >
          {showForm ? <><X size={16} /> Cancelar</> : <>➕ Novo Tenant</>}
        </button>
      </div>

      <div className="page-content">
        {error && (
          <div className="alert alert-error">
            ⚠️ {error}
          </div>
        )}

        {/* Create/Edit Form */}
        {showForm && (
          <div className="content-section">
            <div className="section-header">
              <h2 className="section-title">
                {editingTenant ? 'Editar Tenant' : 'Criar Novo Tenant'}
              </h2>
            </div>

            <form onSubmit={handleSubmit}>
              <div className="form-row">
                <div className="form-group">
                  <label>Nome do Tenant *</label>
                  <input
                    type="text"
                    value={formData.name}
                    onChange={e => setFormData({ ...formData, name: e.target.value })}
                    placeholder="Ex: Empresa XYZ"
                    required
                  />
                </div>

                <div className="form-group">
                  <label>Chatwoot Host</label>
                  <input
                    type="url"
                    value={formData.chatwoot_host}
                    onChange={e => setFormData({ ...formData, chatwoot_host: e.target.value })}
                    placeholder="https://chatwoot.example.com (opcional)"
                  />
                </div>
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label>Chatwoot Account ID {editingTenant ? '' : '*'} </label>
                  <input
                    type="number"
                    value={formData.chatwoot_account_id}
                    onChange={e => setFormData({ ...formData, chatwoot_account_id: e.target.value })}
                    placeholder="ID da conta no Chatwoot"
                    required={!editingTenant}
                    disabled={!!editingTenant}
                  />
                  {editingTenant && (
                    <small className="form-help">O ID da conta é o identificador do tenant e não pode ser alterado</small>
                  )}
                </div>

                <div className="form-group">
                  <label>Chatwoot Account Name</label>
                  <input
                    type="text"
                    value={formData.chatwoot_account_name}
                    onChange={e => setFormData({ ...formData, chatwoot_account_name: e.target.value })}
                    placeholder="Nome da conta (opcional)"
                  />
                </div>
              </div>

              <div className="form-group">
                <label className="checkbox-label">
                  <input
                    type="checkbox"
                    checked={formData.is_active}
                    onChange={e => setFormData({ ...formData, is_active: e.target.checked })}
                  />
                  Tenant Ativo
                </label>
              </div>

              <div className="form-actions">
                <button type="button" className="btn-secondary" onClick={resetForm}>
                  Cancelar
                </button>
                <button type="submit" className="btn-primary">
                  {editingTenant ? 'Atualizar Tenant' : 'Criar Tenant'}
                </button>
              </div>
            </form>
          </div>
        )}

        {/* Tenants Table */}
        <div className="content-section">
          <div className="tenants-table-container">
            <table className="tenants-table">
              <thead>
                <tr>
                  <th>Nome</th>
                  <th>Chatwoot Account</th>
                  <th>Status</th>
                  <th>Criado em</th>
                  <th>Ações</th>
                </tr>
              </thead>
              <tbody>
                {tenants.length === 0 ? (
                  <tr>
                    <td colSpan="5" className="text-center">
                      Nenhum tenant encontrado
                    </td>
                  </tr>
                ) : (
                  tenants.map(tenant => (
                    <tr key={tenant.id}>
                      <td><strong>{tenant.name}</strong></td>
                      <td>
                        {tenant.chatwoot_account_id ? (
                          <>
                            <strong>ID:</strong> {tenant.chatwoot_account_id}
                            {tenant.chatwoot_account_name && (
                              <><br/><small>{tenant.chatwoot_account_name}</small></>
                            )}
                          </>
                        ) : (
                          <span className="text-muted">N/A</span>
                        )}
                      </td>
                      <td>
                        <span className={`status-badge ${tenant.is_active ? 'active' : 'inactive'}`}>
                          {tenant.is_active ? 'Ativo' : 'Inativo'}
                        </span>
                      </td>
                      <td>{new Date(tenant.created_at).toLocaleDateString('pt-BR')}</td>
                      <td className="actions-cell">
                        <button 
                          className="btn-icon btn-edit" 
                          onClick={() => handleEdit(tenant)}
                          title="Editar tenant"
                        >
                          <Edit size={16} />
                        </button>
                        <button 
                          className="btn-icon btn-danger" 
                          onClick={() => handleDelete(tenant.id, tenant.name)}
                          title="Excluir tenant"
                        >
                          <Trash2 size={16} />
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>

          <div className="tenants-summary">
            Total: <strong>{tenants.length}</strong> tenants
          </div>
        </div>
      </div>
    </div>
  );
};

export default TenantsManagement;
