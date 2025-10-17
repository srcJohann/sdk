/**
 * Create Tenant Form Component
 * 
 * Form for creating new tenants with validation
 */
import React, { useState } from 'react';
import { createTenant } from '../../services/adminService';
import './CreateTenantForm.css';

const CreateTenantForm = ({ onSuccess, onCancel }) => {
  const [formData, setFormData] = useState({
    name: '',
    chatwootAccountId: '',
    chatwootAccountName: '',
    chatwootHost: '',
  });

  const [errors, setErrors] = useState({});
  const [loading, setLoading] = useState(false);
  const [apiError, setApiError] = useState(null);

  // Validate form
  const validate = () => {
    const newErrors = {};

    // Name validation
    if (!formData.name.trim()) {
      newErrors.name = 'Nome é obrigatório';
    } else if (formData.name.length < 3) {
      newErrors.name = 'Nome deve ter pelo menos 3 caracteres';
    } else if (formData.name.length > 255) {
      newErrors.name = 'Nome muito longo (máximo 255 caracteres)';
    }

    // Chatwoot Account ID is required and must be numeric (used as tenant_id)
    if (!formData.chatwootAccountId || !formData.chatwootAccountId.toString().trim()) {
      newErrors.chatwootAccountId = 'ID da conta Chatwoot é obrigatório e será usado como tenant_id';
    } else if (!/^[0-9]+$/.test(formData.chatwootAccountId)) {
      newErrors.chatwootAccountId = 'ID da conta deve ser um número';
    }

    // Chatwoot Account ID (optional, but must be number if provided)
    if (formData.chatwootAccountId && !/^\d+$/.test(formData.chatwootAccountId)) {
      newErrors.chatwootAccountId = 'ID da conta deve ser um número';
    }

    // Chatwoot Host (optional, but must be valid URL if provided)
    if (formData.chatwootHost && !/^https?:\/\/.+/.test(formData.chatwootHost)) {
      newErrors.chatwootHost = 'Host deve ser uma URL válida (http:// ou https://)';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  // Auto-generate slug from name
  const handleNameChange = (e) => {
    const name = e.target.value;
    setFormData(prev => ({ ...prev, name }));
    
    // Clear name error
    if (errors.name) {
      setErrors(prev => ({ ...prev, name: null }));
    }
  };

  const slugify = (text) => {
    return text
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '') // Remove diacritics
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, ''); // Trim hyphens
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
    
    // Clear field error
    if (errors[name]) {
      setErrors(prev => ({ ...prev, [name]: null }));
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setApiError(null);

    if (!validate()) {
      return;
    }

    setLoading(true);

    try {
      const payload = {
        name: formData.name.trim(),
        // slug removed: backend will use chatwoot_account_id as identifier
        slug: null,
        chatwootAccountId: parseInt(formData.chatwootAccountId),
        chatwootAccountName: formData.chatwootAccountName.trim() || null,
        chatwootHost: formData.chatwootHost.trim() || null,
      };

      const newTenant = await createTenant(payload);
      
      // Success callback
      if (onSuccess) {
        onSuccess(newTenant);
      }
    } catch (err) {
      console.error('Error creating tenant:', err);
      setApiError(err.message || 'Erro ao criar tenant');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="create-tenant-form">
      <div className="form-header">
        <h2>Criar Novo Tenant</h2>
        <button
          type="button"
          className="btn-close"
          onClick={onCancel}
          disabled={loading}
        >
          ✕
        </button>
      </div>

      <form onSubmit={handleSubmit}>
        {/* API Error */}
        {apiError && (
          <div className="form-error">
            <span>⚠️ {apiError}</span>
          </div>
        )}

        {/* Name + Chatwoot Host on same row */}
        <div className="form-row">
          <div className="form-group">
            <label htmlFor="name">
              Nome do Tenant <span className="required">*</span>
            </label>
            <input
              type="text"
              id="name"
              name="name"
              value={formData.name}
              onChange={handleNameChange}
              disabled={loading}
              className={errors.name ? 'error' : ''}
              placeholder="Ex: Empresa ABC"
              autoFocus
            />
            {errors.name && <span className="field-error">{errors.name}</span>}
          </div>

          <div className="form-group">
            <label htmlFor="chatwootHost">Host Chatwoot</label>
            <input
              type="text"
              id="chatwootHost"
              name="chatwootHost"
              value={formData.chatwootHost}
              onChange={handleChange}
              disabled={loading}
              className={errors.chatwootHost ? 'error' : ''}
              placeholder="https://chatwoot.example.com (opcional)"
            />
            {errors.chatwootHost && (
              <span className="field-error">{errors.chatwootHost}</span>
            )}
          </div>
        </div>

        {/* Chatwoot Integration (Optional) */}
        <div className="form-section">
          <h3>Integração Chatwoot (Opcional)</h3>

          <div className="form-row">
            <div className="form-group">
              <label htmlFor="chatwootAccountId">ID da Conta Chatwoot <span className="required">*</span></label>
              <input
                type="text"
                id="chatwootAccountId"
                name="chatwootAccountId"
                value={formData.chatwootAccountId}
                onChange={handleChange}
                disabled={loading}
                className={errors.chatwootAccountId ? 'error' : ''}
                placeholder="Ex: 123"
              />
              {errors.chatwootAccountId && (
                <span className="field-error">{errors.chatwootAccountId}</span>
              )}
              <span className="field-hint">
                Este ID será usado como identificador único do tenant (tenant_id).
              </span>
            </div>

            <div className="form-group">
              <label htmlFor="chatwootAccountName">Nome da Conta Chatwoot</label>
              <input
                type="text"
                id="chatwootAccountName"
                name="chatwootAccountName"
                value={formData.chatwootAccountName}
                onChange={handleChange}
                disabled={loading}
                placeholder="Ex: Conta Principal"
              />
            </div>
          </div>
        </div>

        {/* Actions */}
        <div className="form-actions">
          <button
            type="button"
            className="btn btn-secondary"
            onClick={onCancel}
            disabled={loading}
          >
            Cancelar
          </button>
          <button
            type="submit"
            className="btn btn-primary"
            disabled={loading}
          >
            {loading ? 'Criando...' : 'Criar Tenant'}
          </button>
        </div>
      </form>
    </div>
  );
};

export default CreateTenantForm;
