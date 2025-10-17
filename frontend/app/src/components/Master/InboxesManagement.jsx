/**
 * Inboxes Management - Master Admin
 * Full CRUD for inbox management with agent type configuration
 */
import React, { useState, useEffect } from 'react';
import { Inbox, Edit, Trash2, X } from 'lucide-react';
import adminService from '../../services/adminService';
import './InboxesManagement.css';

const InboxesManagement = () => {
  const [inboxes, setInboxes] = useState([]);
  const [tenants, setTenants] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [showForm, setShowForm] = useState(false);
  const [editingInbox, setEditingInbox] = useState(null);
  const [filterTenant, setFilterTenant] = useState('');
  const [formData, setFormData] = useState({
    tenant_id: '',
    name: '',
    external_id: '',
    agent_type: 'SDR',
    is_active: true
  });

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setLoading(true);
      setError(null);
      const [inboxesData, tenantsData] = await Promise.all([
        adminService.listAllInboxes(),
        adminService.listTenants()
      ]);
      setInboxes(inboxesData);
      setTenants(tenantsData);
    } catch (err) {
      console.error('Error loading data:', err);
      setError(err.message || 'Erro ao carregar dados');
    } finally {
      setLoading(false);
    }
  };

  const resetForm = () => {
    setFormData({
      tenant_id: '',
      name: '',
      external_id: '',
      agent_type: 'SDR',
      is_active: true
    });
    setEditingInbox(null);
    setShowForm(false);
  };

  const handleEdit = (inbox) => {
    setEditingInbox(inbox);
    setFormData({
      tenant_id: inbox.tenant_id,
      name: inbox.name,
      external_id: inbox.external_id || '',
      agent_type: inbox.agent_type || 'SDR',
      is_active: inbox.is_active
    });
    setShowForm(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);

    try {
      const data = {
        tenant_id: formData.tenant_id,
        name: formData.name.trim(),
        external_id: formData.external_id.trim() || null,
        agent_type: formData.agent_type,
        is_active: formData.is_active
      };

      if (editingInbox) {
        // Update
        await adminService.updateInbox(editingInbox.id, data);
        alert('Inbox atualizado com sucesso!');
      } else {
        // Create
        await adminService.createInbox(data);
        alert('Inbox criado com sucesso!');
      }

      resetForm();
      loadData();
    } catch (err) {
      console.error('Error saving inbox:', err);
      setError(err.message || 'Erro ao salvar inbox');
    }
  };

  const handleDelete = async (inboxId, inboxName) => {
    if (!confirm(`Tem certeza que deseja excluir o inbox "${inboxName}"?\n\nATENÇÃO: Todas as conversas e mensagens serão perdidas!`)) {
      return;
    }

    try {
      setError(null);
      await adminService.deleteInbox(inboxId);
      alert('Inbox excluído com sucesso!');
      loadData();
    } catch (err) {
      console.error('Error deleting inbox:', err);
      setError(err.message || 'Erro ao excluir inbox');
    }
  };

  const filteredInboxes = filterTenant
    ? inboxes.filter(inbox => inbox.tenant_id === filterTenant)
    : inboxes;

  if (loading) {
    return <div className="loading">Carregando inboxes...</div>;
  }

  return (
    <div className="page-container">
      <div className="page-header">
        <h1 className="page-title">
          <Inbox size={24} />
          Gerenciamento de Inboxes
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
          {showForm ? <><X size={16} /> Cancelar</> : <>➕ Novo Inbox</>}
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
                {editingInbox ? 'Editar Inbox' : 'Criar Novo Inbox'}
              </h2>
            </div>

            <form onSubmit={handleSubmit}>
              <div className="form-row">
                <div className="form-group">
                  <label>Tenant *</label>
                  <select
                    value={formData.tenant_id}
                    onChange={e => setFormData({ ...formData, tenant_id: e.target.value })}
                    required
                    disabled={!!editingInbox}
                  >
                    <option value="">Selecione um Tenant</option>
                    {tenants.map(tenant => (
                      <option key={tenant.id} value={tenant.id}>
                        {tenant.name}
                      </option>
                    ))}
                  </select>
                  {editingInbox && (
                    <small className="form-help">O tenant não pode ser alterado após a criação</small>
                  )}
                </div>

                <div className="form-group">
                  <label>Nome do Inbox *</label>
                  <input
                    type="text"
                    value={formData.name}
                    onChange={e => setFormData({ ...formData, name: e.target.value })}
                    placeholder="Ex: WhatsApp Suporte"
                    required
                  />
                </div>
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label>Chatwoot Inbox ID</label>
                  <input
                    type="number"
                    value={formData.external_id}
                    onChange={e => setFormData({ ...formData, external_id: e.target.value })}
                    placeholder="Ex: 27"
                  />
                  <small className="form-help">ID do inbox no Chatwoot (número inteiro)</small>
                </div>

                <div className="form-group">
                  <label>Tipo de Agente *</label>
                  <select
                    value={formData.agent_type}
                    onChange={e => setFormData({ ...formData, agent_type: e.target.value })}
                    required
                  >
                    <option value="SDR">SDR (Pré-vendas)</option>
                    <option value="COPILOT">COPILOT (Assistente)</option>
                  </select>
                  <small className="form-help">
                    SDR: Qualificação de leads e agendamento
                    <br/>
                    COPILOT: Suporte e atendimento ao cliente
                  </small>
                </div>
              </div>

              <div className="form-group">
                <label className="checkbox-label">
                  <input
                    type="checkbox"
                    checked={formData.is_active}
                    onChange={e => setFormData({ ...formData, is_active: e.target.checked })}
                  />
                  Inbox Ativo
                </label>
              </div>

              <div className="form-actions">
                <button type="button" className="btn-secondary" onClick={resetForm}>
                  Cancelar
                </button>
                <button type="submit" className="btn-primary">
                  {editingInbox ? 'Atualizar Inbox' : 'Criar Inbox'}
                </button>
              </div>
            </form>
          </div>
        )}

        {/* Filter */}
        <div className="content-section">
          <div className="filters-bar">
            <div className="filter-group">
              <label>Filtrar por Tenant:</label>
              <select value={filterTenant} onChange={e => setFilterTenant(e.target.value)}>
                <option value="">Todos os Tenants</option>
                {tenants.map(tenant => (
                  <option key={tenant.id} value={tenant.id}>{tenant.name}</option>
                ))}
              </select>
            </div>

            {filterTenant && (
              <button 
                className="btn-filter" 
                onClick={() => setFilterTenant('')}
              >
                Limpar Filtro
              </button>
            )}
          </div>
        </div>

        {/* Inboxes Table */}
        <div className="content-section">
          <div className="inboxes-table-container">
            <table className="inboxes-table">
              <thead>
                <tr>
                  <th>Nome</th>
                  <th>Tenant</th>
                  <th>Chatwoot ID</th>
                  <th>Tipo de Agente</th>
                  <th>Status</th>
                  <th>Conversas</th>
                  <th>Ações</th>
                </tr>
              </thead>
              <tbody>
                {filteredInboxes.length === 0 ? (
                  <tr>
                    <td colSpan="7" className="text-center">
                      Nenhum inbox encontrado
                    </td>
                  </tr>
                ) : (
                  filteredInboxes.map(inbox => (
                    <tr key={inbox.id}>
                      <td><strong>{inbox.name}</strong></td>
                      <td>{inbox.tenant_name}</td>
                      <td>
                        {inbox.external_id ? (
                          <code>{inbox.external_id}</code>
                        ) : (
                          <span className="text-muted">N/A</span>
                        )}
                      </td>
                      <td>
                        <span className={`agent-badge agent-${inbox.agent_type?.toLowerCase() || 'sdr'}`}>
                          {inbox.agent_type || 'SDR'}
                        </span>
                      </td>
                      <td>
                        <span className={`status-badge ${inbox.is_active ? 'active' : 'inactive'}`}>
                          {inbox.is_active ? 'Ativo' : 'Inativo'}
                        </span>
                      </td>
                      <td>{inbox.conversation_count || 0}</td>
                      <td className="actions-cell">
                        <button 
                          className="btn-icon btn-edit" 
                          onClick={() => handleEdit(inbox)}
                          title="Editar inbox"
                        >
                          <Edit size={16} />
                        </button>
                        <button 
                          className="btn-icon btn-danger" 
                          onClick={() => handleDelete(inbox.id, inbox.name)}
                          title="Excluir inbox"
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

          <div className="inboxes-summary">
            Total: <strong>{filteredInboxes.length}</strong> inboxes
            {filterTenant && ` (${inboxes.length} no sistema)`}
          </div>
        </div>
      </div>
    </div>
  );
};

export default InboxesManagement;
