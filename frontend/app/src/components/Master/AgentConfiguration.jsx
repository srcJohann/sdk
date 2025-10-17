/**
 * Agent Configuration - Master-only
 * Configure SDR Agent and COPILOT Agent endpoints and parameters
 */
import React, { useState, useEffect } from 'react';
import { Bot, TestTube, Save, RotateCcw } from 'lucide-react';
import adminService from '../../services/adminService';
import './AgentConfiguration.css';

const AgentConfiguration = () => {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [testing, setTesting] = useState(false);
  const [error, setError] = useState(null);
  const [testResult, setTestResult] = useState(null);
  const [activeAgentType, setActiveAgentType] = useState('SDR'); // 'SDR' or 'COPILOT'
  
  const [config, setConfig] = useState({
    sdr_agent_endpoint: '',
    sdr_agent_api_key: '',
    sdr_agent_timeout_ms: 30000,
    health_check_enabled: true,
    health_check_interval_seconds: 60,
    server_config: {}
  });

  const [serverConfigJson, setServerConfigJson] = useState('{}');

  useEffect(() => {
    loadConfig();
  }, []);

  const loadConfig = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await adminService.getMasterSettings();
      
      if (data) {
        setConfig({
          sdr_agent_endpoint: data.sdr_agent_endpoint || '',
          sdr_agent_api_key: data.sdr_agent_api_key || '',
          sdr_agent_timeout_ms: data.sdr_agent_timeout_ms || 30000,
          health_check_enabled: data.health_check_enabled !== false,
          health_check_interval_seconds: data.health_check_interval_seconds || 60,
          server_config: data.server_config || {}
        });
        
        setServerConfigJson(JSON.stringify(data.server_config || {}, null, 2));
      }
    } catch (err) {
      console.error('Error loading config:', err);
      setError(err.message || 'Erro ao carregar configuração');
    } finally {
      setLoading(false);
    }
  };

  const handleSaveConfig = async () => {
    try {
      setSaving(true);
      setError(null);

      // Validate JSON
      let parsedConfig = {};
      try {
        parsedConfig = JSON.parse(serverConfigJson);
      } catch (e) {
        throw new Error('Configuração JSON inválida');
      }

      // Validate endpoint
      if (config.sdr_agent_endpoint && !isValidUrl(config.sdr_agent_endpoint)) {
        throw new Error('Endpoint inválido. Use formato: http://domain:port ou https://domain');
      }

      await adminService.updateMasterSettings({
        sdrAgentEndpoint: config.sdr_agent_endpoint,
        sdrAgentApiKey: config.sdr_agent_api_key,
        sdrAgentTimeoutMs: parseInt(config.sdr_agent_timeout_ms),
        healthCheckEnabled: config.health_check_enabled,
        healthCheckIntervalSeconds: parseInt(config.health_check_interval_seconds),
        serverConfig: parsedConfig
      });

      alert('✅ Configuração salva com sucesso!');
    } catch (err) {
      console.error('Error saving config:', err);
      setError(err.message || 'Erro ao salvar configuração');
    } finally {
      setSaving(false);
    }
  };

  const handleTestConnection = async () => {
    try {
      setTesting(true);
      setTestResult(null);
      setError(null);

      const result = await adminService.testSdrHealthCheck();
      
      setTestResult({
        success: result.status === 'healthy',
        message: result.message || 'Conexão estabelecida com sucesso',
        details: result
      });
    } catch (err) {
      console.error('Error testing connection:', err);
      setTestResult({
        success: false,
        message: err.message || 'Falha ao conectar com o agente',
        details: null
      });
    } finally {
      setTesting(false);
    }
  };

  const isValidUrl = (string) => {
    try {
      const url = new URL(string);
      return url.protocol === 'http:' || url.protocol === 'https:';
    } catch (_) {
      return false;
    }
  };

  const handleJsonChange = (value) => {
    setServerConfigJson(value);
  };

  if (loading) {
    return (
      <div className="page-container">
        <div className="page-header">
          <h1 className="page-title">
            <Bot size={24} />
            Configuração do Agente IA
          </h1>
        </div>
        <div className="page-content">
          <div className="loading-message">Carregando configurações...</div>
        </div>
      </div>
    );
  }

  return (
    <div className="page-container">
      <div className="page-header">
        <h1 className="page-title">
          <Bot size={24} />
          Configuração do Agente IA
        </h1>
        <div className="header-actions">
          <button 
            className="btn-icon"
            onClick={handleTestConnection}
            disabled={testing || !config.sdr_agent_endpoint}
            title="Testar Conexão"
          >
            <TestTube size={18} />
            {testing ? 'Testando...' : 'Testar Conexão'}
          </button>
          <button 
            className="btn-primary"
            onClick={handleSaveConfig}
            disabled={saving}
          >
            <Save size={18} />
            {saving ? 'Salvando...' : 'Salvar'}
          </button>
        </div>
      </div>

      <div className="page-content">
        {error && (
          <div className="alert alert-error">
            {error}
          </div>
        )}

        {testResult && (
          <div className={`alert ${testResult.success ? 'alert-success' : 'alert-error'}`}>
            {testResult.message}
          </div>
        )}

        {/* Agent Type Toggle */}
        <div className="agent-type-toggle">
          <button
            className={`toggle-btn ${activeAgentType === 'SDR' ? 'active' : ''}`}
            onClick={() => setActiveAgentType('SDR')}
          >
            Agente SDR
          </button>
          <button
            className={`toggle-btn ${activeAgentType === 'COPILOT' ? 'active' : ''}`}
            onClick={() => setActiveAgentType('COPILOT')}
          >
            Agente COPILOT
          </button>
        </div>

        {activeAgentType === 'SDR' && (
          <>
            <div className="content-section">
              <div className="section-header">
                <h2>Endpoint do Agente SDR</h2>
                <p className="section-description">
                  Configure a URL completa do seu agente de IA para qualificação de leads.
                </p>
              </div>
              
              <div className="form-group">
                <label>Endpoint URL *</label>
                <input
                  type="url"
                  value={config.sdr_agent_endpoint}
                  onChange={e => setConfig({ ...config, sdr_agent_endpoint: e.target.value })}
                  placeholder="https://api.seuagente.com/v1"
                  className="input-large"
                />
                <span className="help-text">
                  Exemplo: http://localhost:8000 ou https://api.example.com/agent
                </span>
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label>API Key (Opcional)</label>
                  <input
                    type="password"
                    value={config.sdr_agent_api_key}
                    onChange={e => setConfig({ ...config, sdr_agent_api_key: e.target.value })}
                    placeholder="sk-..."
                  />
                </div>

                <div className="form-group">
                  <label>Timeout (ms)</label>
                  <input
                    type="number"
                    value={config.sdr_agent_timeout_ms}
                    onChange={e => setConfig({ ...config, sdr_agent_timeout_ms: e.target.value })}
                    min="1000"
                    max="120000"
                  />
                </div>
              </div>
            </div>

            <div className="content-section">
              <div className="section-header">
                <h2>Health Check</h2>
                <p className="section-description">
                  Monitore a disponibilidade do agente automaticamente.
                </p>
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label className="checkbox-label">
                    <input
                      type="checkbox"
                      checked={config.health_check_enabled}
                      onChange={e => setConfig({ ...config, health_check_enabled: e.target.checked })}
                    />
                    <span>Habilitar Health Check Automático</span>
                  </label>
                </div>

                {config.health_check_enabled && (
                  <div className="form-group">
                    <label>Intervalo (segundos)</label>
                    <input
                      type="number"
                      value={config.health_check_interval_seconds}
                      onChange={e => setConfig({ ...config, health_check_interval_seconds: e.target.value })}
                      min="10"
                      max="3600"
                    />
                  </div>
                )}
              </div>
            </div>

            <div className="content-section">
              <div className="section-header">
                <h2>Configurações Avançadas (JSON)</h2>
                <p className="section-description">
                  Configure parâmetros adicionais do agente em formato JSON.
                </p>
              </div>

              <div className="form-group">
                <label>Server Config</label>
                <textarea
                  className="json-editor"
                  value={serverConfigJson}
                  onChange={e => handleJsonChange(e.target.value)}
                  placeholder='{"temperature": 0.7, "max_tokens": 2000}'
                  rows={10}
                  spellCheck={false}
                />
                <span className="help-text">
                  JSON válido com configurações personalizadas do agente
                </span>
              </div>
            </div>

            <div className="form-actions">
              <button className="btn-secondary" onClick={loadConfig}>
                <RotateCcw size={18} />
                Recarregar
              </button>
              <button 
                className="btn-primary"
                onClick={handleSaveConfig}
                disabled={saving}
              >
                <Save size={18} />
                {saving ? 'Salvando...' : 'Salvar Configuração'}
              </button>
            </div>
          </>
        )}

        {activeAgentType === 'COPILOT' && (
          <div className="content-section">
            <div className="section-header">
              <h2>Agente COPILOT</h2>
              <p className="section-description">
                As configurações do Agente COPILOT ainda não foram implementadas. Em breve você poderá configurar o agente de suporte ao cliente aqui.
              </p>
            </div>
            <div className="coming-soon">
              <p>🚧 Funcionalidade em desenvolvimento</p>
              <p className="help-text">O endpoint do Agente COPILOT será adicionado em uma próxima versão.</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default AgentConfiguration;
