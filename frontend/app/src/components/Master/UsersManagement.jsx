/**
 * Users Management for Master Admin
 * 
 * Permite ao Master criar/editar usuários de qualquer tenant
 * e associar inbox_id específico
 */
import React, { useState, useEffect } from 'react';
import { Users, Search, X, Edit, Trash2 } from 'lucide-react';
import adminService from '../../services/adminService';
import './UsersManagement.css';

const UsersManagement = () => {
  const [users, setUsers] = useState([]);
  const [tenants, setTenants] = useState([]);
  const [inboxes, setInboxes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [selectedUser, setSelectedUser] = useState(null);
  const [filters, setFilters] = useState({
    tenant_id: '',
    role: '',
    is_active: ''
  });

  // Form state
  const [formData, setFormData] = useState({
    name: '',
    username: '',
    email: '',
    password: '',
    tenant_id: '',
    role: 'TENANT_USER',
    is_active: true
  });

  useEffect(() => {
    loadData();
  }, [filters]);

  const loadData = async () => {
    try {
      setLoading(true);
      setError(null);

      console.log('[UsersManagement] Loading data with filters:', filters);

      // Build clean filters object (remove empty strings)
      const cleanFilters = {};
      if (filters.tenant_id) cleanFilters.tenant_id = filters.tenant_id;
      if (filters.role) cleanFilters.role = filters.role;
      if (filters.is_active !== '') {
        // Convert string 'true'/'false' to boolean, or leave as boolean
        cleanFilters.is_active = filters.is_active === 'true' || filters.is_active === true;
      }

      console.log('[UsersManagement] Clean filters:', cleanFilters);

      // Load users with filters
      const usersData = await adminService.listUsers(cleanFilters);
      console.log('[UsersManagement] Users loaded:', usersData);
      setUsers(usersData);

      // Load tenants for dropdowns
      const tenantsData = await adminService.listTenants();
      console.log('[UsersManagement] Tenants loaded:', tenantsData);
      setTenants(tenantsData);

      // Load all inboxes
      const inboxesData = await adminService.listAllInboxes();
      console.log('[UsersManagement] Inboxes loaded:', inboxesData);
      setInboxes(inboxesData);

    } catch (err) {
      console.error('[UsersManagement] Error loading data:', err);
      console.error('[UsersManagement] Error type:', typeof err);
      console.error('[UsersManagement] Error message:', err.message);
      console.error('[UsersManagement] Error stack:', err.stack);
      setError(err.message || String(err) || 'Erro ao carregar dados');
    } finally {
      setLoading(false);
    }
  };

  const handleCreateUser = async (e) => {
    e.preventDefault();
    
    try {
      setError(null);

      // Validate
      // Password is required only when creating a new user
      const isCreating = !selectedUser;

      if (!formData.name || !formData.email || !formData.tenant_id || (isCreating && !formData.password)) {
        console.debug('[UsersManagement] Validation failed, formData:', formData, 'isCreating:', isCreating);
        throw new Error('Preencha todos os campos obrigatórios');
      }

      // Basic email check
      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(formData.email)) {
        throw new Error('Email inválido');
      }

      // Create user (without inbox_ids for now - access is controlled by tenant)
      if (selectedUser) {
        // Update path: build updates object (don't send empty password)
        const updates = {
          name: formData.name,
          username: formData.username,
          email: formData.email,
          tenant_id: formData.tenant_id,
          role: formData.role,
          is_active: formData.is_active
        };
        if (formData.password) updates.password = formData.password;

        await handleUpdateUser(selectedUser.id, updates);
        // Clear selection after update
        setSelectedUser(null);
      } else {
        const newUser = await adminService.createUser(formData);
        alert('Usuário criado com sucesso!');
      }

      // Reset form
      setFormData({
        name: '',
        username: '',
        email: '',
        password: '',
        tenant_id: '',
        role: 'TENANT_USER',
        is_active: true
      });
      setShowCreateForm(false);

      // Reload users
      loadData();

    } catch (err) {
      console.error('Error creating user:', err);
      setError(err.message || 'Erro ao criar usuário');
    }
  };

  const closeForm = () => {
    setShowCreateForm(false);
    setSelectedUser(null);
    setFormData({
      name: '',
      username: '',
      email: '',
      password: '',
      tenant_id: '',
      role: 'TENANT_USER',
      is_active: true
    });
  };

  const handleEditUser = (user) => {
    setSelectedUser(user);
    setFormData({
      name: user.name || '',
      username: user.username || '',
      email: user.email || '',
      password: '', // never prefill password
      tenant_id: user.tenant_id || '',
      role: user.role || 'TENANT_USER',
      is_active: user.is_active !== undefined ? user.is_active : true
    });
    setShowCreateForm(true);
  };

  const handleUpdateUser = async (userId, updates) => {
    try {
      setError(null);
      await adminService.updateUser(userId, updates);
      alert('Usuário atualizado com sucesso!');
      loadData();
    } catch (err) {
      console.error('Error updating user:', err);
      setError(err.message || 'Erro ao atualizar usuário');
    }
  };

  const handleDeleteUser = async (userId) => {
    if (!confirm('Tem certeza que deseja desativar este usuário?')) return;
    
    try {
      setError(null);
      await adminService.deleteUser(userId);
      alert('Usuário desativado com sucesso!');
      loadData();
    } catch (err) {
      console.error('Error deleting user:', err);
      setError(err.message || 'Erro ao desativar usuário');
    }
  };

  const handleInboxToggle = (inboxId) => {
    // Removed - inbox access controlled by tenant
  };

  const getTenantName = (tenantId) => {
    const tenant = tenants.find(t => t.id === tenantId);
    return tenant ? tenant.name : 'N/A';
  };

  const getAvailableInboxes = () => {
    // Removed - inbox access controlled by tenant
    return [];
  };

  if (loading) {
    return <div className="loading">Carregando usuários...</div>;
  }

  return (
    <div className="page-container">
      <div className="page-header">
        <h1 className="page-title">
          <Users size={24} />
          Gestão de Usuários
        </h1>
        <button 
          className="btn-filter"
          onClick={() => setShowCreateForm(!showCreateForm)}
        >
          {showCreateForm ? <><X size={16} /> Cancelar</> : <>➕ Criar Usuário</>}
        </button>
      </div>

      <div className="page-content">
        {error && (
          <div className="alert alert-error">
            ⚠️ {error}
          </div>
        )}

        {/* Create User Form */}
        {showCreateForm && (
          <div className="content-section">
            <div className="section-header">
              <h2 className="section-title">{selectedUser ? 'Editar Usuário' : 'Criar Novo Usuário'}</h2>
            </div>
            <form onSubmit={handleCreateUser}>
              <div className="form-row">
                <div className="form-group">
                  <label>Nome Completo *</label>
                  <input
                    type="text"
                    value={formData.name}
                    onChange={e => setFormData({ ...formData, name: e.target.value })}
                    placeholder="Ex: João Silva"
                    required
                  />
                </div>

                <div className="form-group">
                  <label>Username *</label>
                  <input
                    type="text"
                    value={formData.username}
                    onChange={e => setFormData({ ...formData, username: e.target.value })}
                    placeholder="Ex: joaosilva"
                    required
                  />
                </div>
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label>Email *</label>
                  <input
                    type="email"
                    value={formData.email}
                    onChange={e => setFormData({ ...formData, email: e.target.value })}
                    placeholder="email@example.com"
                    required
                  />
                </div>

                <div className="form-group">
                  <label>Senha {selectedUser ? '(deixe em branco para manter)' : '*'}</label>
                  <input
                    type="password"
                    value={formData.password}
                    onChange={e => setFormData({ ...formData, password: e.target.value })}
                    placeholder={selectedUser ? 'Deixe em branco para manter a senha atual' : 'Mínimo 8 caracteres'}
                    {...(selectedUser ? {} : { required: true, minLength: 8 })}
                  />
                </div>
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label>Tenant *</label>
                  <select
                    value={formData.tenant_id}
                    onChange={e => {
                      setFormData({ ...formData, tenant_id: e.target.value });
                      setSelectedInboxIds([]); // Reset inbox selection
                    }}
                    required
                  >
                    <option value="">Selecione um Tenant</option>
                    {tenants.map(tenant => (
                      <option key={tenant.id} value={tenant.id}>
                        {tenant.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div className="form-group">
                  <label>Role *</label>
                  <select
                    value={formData.role}
                    onChange={e => setFormData({ ...formData, role: e.target.value })}
                    required
                  >
                    <option value="MASTER">MASTER (Administrador Global)</option>
                    <option value="TENANT_ADMIN">TENANT_ADMIN (Admin do Tenant)</option>
                    <option value="TENANT_USER">TENANT_USER (Usuário Comum)</option>
                  </select>
                </div>
              </div>

              <div className="form-group">
                <label className="checkbox-label">
                  <input
                    type="checkbox"
                    checked={formData.is_active}
                    onChange={e => setFormData({ ...formData, is_active: e.target.checked })}
                  />
                  Usuário Ativo
                </label>
              </div>

              <div className="form-actions">
                <button type="button" className="btn-secondary" onClick={closeForm}>
                  Cancelar
                </button>
                <button type="submit" className="btn-primary">
                  {selectedUser ? 'Atualizar Usuário' : 'Criar Usuário'}
                </button>
              </div>
            </form>
          </div>
        )}

        {/* Filters */}
        <div className="content-section">
          <div className="filters-bar">
            <div className="filter-group">
              <label>Tenant:</label>
              <select 
                value={filters.tenant_id} 
                onChange={e => setFilters({ ...filters, tenant_id: e.target.value })}
              >
                <option value="">Todos</option>
                {tenants.map(tenant => (
                  <option key={tenant.id} value={tenant.id}>{tenant.name}</option>
                ))}
              </select>
            </div>

            <div className="filter-group">
              <label>Role:</label>
              <select 
                value={filters.role} 
                onChange={e => setFilters({ ...filters, role: e.target.value })}
              >
                <option value="">Todas</option>
                <option value="MASTER">MASTER</option>
                <option value="TENANT_ADMIN">TENANT_ADMIN</option>
                <option value="TENANT_USER">TENANT_USER</option>
              </select>
            </div>

            <div className="filter-group">
              <label>Status:</label>
              <select 
                value={filters.is_active} 
                onChange={e => setFilters({ ...filters, is_active: e.target.value })}
              >
                <option value="">Todos</option>
                <option value="true">Ativos</option>
                <option value="false">Inativos</option>
              </select>
            </div>

            <button 
              className="btn-filter" 
              onClick={() => setFilters({ tenant_id: '', role: '', is_active: '' })}
            >
              Limpar Filtros
            </button>
          </div>
        </div>

        {/* Users Table */}
        <div className="content-section">
          <div className="users-table-container">
            <table className="users-table">
              <thead>
                <tr>
                  <th>Nome</th>
                  <th>Email</th>
                  <th>Username</th>
                  <th>Tenant</th>
                  <th>Role</th>
                  <th>Status</th>
                  <th>Criado em</th>
                  <th>Ações</th>
                </tr>
              </thead>
              <tbody>
                {users.length === 0 ? (
                  <tr>
                    <td colSpan="8" className="text-center">
                      Nenhum usuário encontrado
                    </td>
                  </tr>
                ) : (
                  users.map(user => (
                    <tr key={user.id}>
                      <td>{user.name}</td>
                      <td>{user.email}</td>
                      <td>{user.username}</td>
                      <td>{user.tenant_id ?? 'N/A'}</td>
                      <td>
                        <span className={`badge badge-${user.role.toLowerCase()}`}>
                          {user.role}
                        </span>
                      </td>
                      <td>
                        <span className={`status-badge ${user.is_active ? 'active' : 'inactive'}`}>
                          {user.is_active ? 'Ativo' : 'Inativo'}
                        </span>
                      </td>
                      <td>{new Date(user.created_at).toLocaleDateString('pt-BR')}</td>
                      <td className="actions-cell">
                        <button 
                          className="btn-icon btn-edit" 
                          onClick={() => handleEditUser(user)}
                          title="Editar usuário"
                        >
                          <Edit size={16} />
                        </button>
                        <button 
                          className="btn-icon btn-danger" 
                          onClick={() => handleDeleteUser(user.id)}
                          title="Excluir usuário"
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

          <div className="users-summary">
            Total: <strong>{users.length}</strong> usuários
          </div>
        </div>
      </div>
    </div>
  );
};

export default UsersManagement;
