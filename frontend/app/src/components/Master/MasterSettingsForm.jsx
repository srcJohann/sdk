/**
 * Master Settings Form - SDR Endpoint Configuration
 */
import React, { useState, useEffect } from 'react';
import { getMasterSettings, updateMasterSettings, testSdrHealthCheck } from '../../services/adminService';
import './MasterSettingsForm.css';

const MasterSettingsForm = () => {
  const [settings, setSettings] = useState(null);
  const [formData, setFormData] = useState({
    sdrAgentEndpoint: '',
    sdrAgentTimeoutMs: 30000,
    serverConfig: {},
  });
  const [configText, setConfigText] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [testing, setTesting] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [healthStatus, setHealthStatus] = useState(null);
  const [configError, setConfigError] = useState(null);

  useEffect(() => {
    loadSettings();
  }, []);

  const loadSettings = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await getMasterSettings();
      setSettings(data);
      setFormData({
        sdrAgentEndpoint: data.sdr_agent_endpoint,
        sdrAgentTimeoutMs: data.sdr_agent_timeout_ms,
        serverConfig: data.server_config,
      });
      setConfigText(JSON.stringify(data.server_config, null, 2));
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleConfigChange = (value) => {
    setConfigText(value);
    setConfigError(null);
    try {
      const parsed = JSON.parse(value);
      setFormData(prev => ({ ...prev, serverConfig: parsed }));
    } catch (err) {
      setConfigError('JSON inválido');
    }
  };

  const handleTestConnection = async () => {
    setTesting(true);
    setHealthStatus(null);
    try {
      const result = await testSdrHealthCheck();
      setHealthStatus(result);
    } catch (err) {
      setHealthStatus({ status: 'unhealthy', error: err.message });
    } finally {
      setTesting(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (configError) return;
    
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      await updateMasterSettings(formData);
      setSuccess('Configurações salvas com sucesso!');
      setTimeout(() => setSuccess(null), 3000);
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  };

  if (loading) return <div className="loading-spinner"><div className="spinner"></div></div>;

  return (
    <div className="master-settings-form">
      <h1>Configurações Master</h1>
      
      {error && <div className="alert alert-error">⚠️ {error}</div>}
      {success && <div className="alert alert-success">✓ {success}</div>}
      
      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label>SDR Agent Endpoint *</label>
          <input
            type="url"
            value={formData.sdrAgentEndpoint}
            onChange={(e) => setFormData(prev => ({ ...prev, sdrAgentEndpoint: e.target.value }))}
            placeholder="http://localhost:8000"
            required
          />
          <button type="button" onClick={handleTestConnection} disabled={testing} className="btn-test">
            {testing ? 'Testando...' : '🔍 Testar Conexão'}
          </button>
        </div>

        {healthStatus && (
          <div className={`health-status ${healthStatus.status}`}>
            {healthStatus.status === 'healthy' ? (
              <span>✓ Endpoint saudável (latência: {healthStatus.latency_ms}ms)</span>
            ) : (
              <span>✗ Falha: {healthStatus.error}</span>
            )}
          </div>
        )}

        <div className="form-group">
          <label>Timeout (ms)</label>
          <input
            type="number"
            value={formData.sdrAgentTimeoutMs}
            onChange={(e) => setFormData(prev => ({ ...prev, sdrAgentTimeoutMs: parseInt(e.target.value) }))}
            min="1000"
            max="120000"
          />
        </div>

        <div className="form-group">
          <label>Server Config (JSON)</label>
          <textarea
            value={configText}
            onChange={(e) => handleConfigChange(e.target.value)}
            rows="12"
            className={configError ? 'error' : ''}
          />
          {configError && <span className="field-error">{configError}</span>}
        </div>

        <div className="form-actions">
          <button type="button" onClick={loadSettings} className="btn-secondary" disabled={saving}>
            Cancelar
          </button>
          <button type="submit" className="btn-primary" disabled={saving || configError}>
            {saving ? 'Salvando...' : 'Salvar Configurações'}
          </button>
        </div>
      </form>
    </div>
  );
};

export default MasterSettingsForm;
