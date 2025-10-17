/**
 * Tenant Users Management - For TENANT_ADMIN role
 * Can only manage users within their own tenant
 */
import React, { useState, useEffect } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import adminService from '../../services/adminService';
import './TenantUsersManagement.css';

const TenantUsersManagement = () => {
  const { user } = useAuth();
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    username: '',
    email: '',
    password: '',
    role: 'TENANT_USER',
    is_active: true
  });

  useEffect(() => {
    loadUsers();
  }, []);

  const loadUsers = async () => {
    try {
      setLoading(true);
      setError(null);
      // Only load users from current tenant
      const data = await adminService.listUsers({ tenant_id: user.tenant_id });
      setUsers(data);
    } catch (err) {
      console.error('Error loading users:', err);
      setError(err.message || 'Erro ao carregar usuários');
    } finally {
      setLoading(false);
    }
  };

  const handleCreateUser = async (e) => {
    e.preventDefault();
    try {
      await adminService.createUser({
        ...formData,
        tenant_id: user.tenant_id // Force current tenant
      });
      alert('Usuário criado com sucesso!');
      setShowCreateForm(false);
      setFormData({ name: '', username: '', email: '', password: '', role: 'TENANT_USER', is_active: true });
      loadUsers();
    } catch (err) {
      console.error('Error creating user:', err);
      alert(`Erro: ${err.message || 'Erro ao criar usuário'}`);
    }
  };

  if (loading) return <div className="view-loading">Carregando usuários...</div>;

  return (
    <div className="tenant-users-view">
      <div className="view-header">
        <h1>Usuários do Tenant</h1>
        <button className="btn-primary" onClick={() => setShowCreateForm(!showCreateForm)}>
          {showCreateForm ? '❌ Cancelar' : '➕ Novo Usuário'}
        </button>
      </div>

      {error && <div className="alert alert-error">⚠️ {error}</div>}

      {showCreateForm && (
        <form onSubmit={handleCreateUser} className="create-form">
          <div className="form-row">
            <div className="form-group">
              <label>Nome</label>
              <input
                type="text"
                value={formData.name}
                onChange={e => setFormData({ ...formData, name: e.target.value })}
                required
              />
            </div>
            <div className="form-group">
              <label>Username</label>
              <input
                type="text"
                value={formData.username}
                onChange={e => setFormData({ ...formData, username: e.target.value })}
                required
              />
            </div>
          </div>
          <div className="form-row">
            <div className="form-group">
              <label>Email</label>
              <input
                type="email"
                value={formData.email}
                onChange={e => setFormData({ ...formData, email: e.target.value })}
                required
              />
            </div>
            <div className="form-group">
              <label>Senha</label>
              <input
                type="password"
                value={formData.password}
                onChange={e => setFormData({ ...formData, password: e.target.value })}
                required
                minLength={8}
              />
            </div>
          </div>
          <div className="form-actions">
            <button type="button" className="btn-secondary" onClick={() => setShowCreateForm(false)}>
              Cancelar
            </button>
            <button type="submit" className="btn-primary">
              Criar Usuário
            </button>
          </div>
        </form>
      )}

      <div className="users-table-container">
        <table className="users-table">
          <thead>
            <tr>
              <th>Nome</th>
              <th>Email</th>
              <th>Username</th>
              <th>Role</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {users.map(u => (
              <tr key={u.id}>
                <td>{u.name}</td>
                <td>{u.email}</td>
                <td>{u.username}</td>
                <td><span className="badge">{u.role}</span></td>
                <td>
                  <span className={`status-badge ${u.is_active ? 'active' : 'inactive'}`}>
                    {u.is_active ? '✓ Ativo' : '✗ Inativo'}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default TenantUsersManagement;
