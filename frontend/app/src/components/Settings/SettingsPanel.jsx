import React, { useState, useEffect } from 'react';
import { Settings, Palette, Bot, Thermometer, Volume2, Globe, Shield, Phone } from 'lucide-react';
import { checkAPIHealth, getAgentConfig } from '../../services/aiService';
import { normalizeToE164, formatPhoneDisplay, isValidE164 } from '../../utils/phoneUtils';
import { useAuth } from '../../contexts/AuthContext';
import './SettingsPanel.css';

const SettingsPanel = ({ settings, onSettingsChange, theme, onThemeChange, phone, onPhoneChange }) => {
  const { user, isMaster } = useAuth();
  const [apiStatus, setApiStatus] = useState(null);
  const [agentConfig, setAgentConfig] = useState(null);
  
  useEffect(() => {
    // Verificar status da API
    checkAPIHealth().then(setApiStatus);
    getAgentConfig().then(setAgentConfig);
  }, []);

  const handleChange = (key, value) => {
    onSettingsChange({ ...settings, [key]: value });
  };
  
  const handlePhoneChange = (e) => {
    let value = e.target.value;
    
    // Remove caracteres não numéricos exceto +
    value = value.replace(/[^\d+]/g, '');
    
    // Normaliza para E.164 (adiciona +55 se necessário)
    if (value && value.length > 2) {
      value = normalizeToE164(value);
    }
    
    onPhoneChange(value);
  };
  
  const getPhoneValidationStatus = () => {
    if (!phone) return null;
    
    const isValid = isValidE164(phone);
    const formatted = formatPhoneDisplay(phone);
    
    return {
      isValid,
      formatted,
      message: isValid 
        ? `✅ Formato válido: ${formatted}` 
        : '⚠️ Formato inválido (use +5524974023279)'
    };
  };

  const aiModels = [
    { id: 'amazon.nova-lite-v1:0', name: 'Amazon Nova Lite', description: 'Modelo padrão SDR' },
    { id: 'gpt-4', name: 'GPT-4', description: 'Mais avançado e preciso' },
    { id: 'gpt-3.5-turbo', name: 'GPT-3.5 Turbo', description: 'Rápido e eficiente' },
  ];

  const languages = [
    { id: 'pt-BR', name: 'Português (Brasil)' },
    { id: 'en-US', name: 'English (US)' },
    { id: 'es-ES', name: 'Español' },
  ];

  return (
    <div className="page-container">
      <div className="page-header">
        <h1 className="page-title">
          <Settings size={24} />
          Configurações SDR
        </h1>
        <p className="page-subtitle">
          Configure o agente Mr. DOM
        </p>
      </div>

      <div className="page-content page-content-centered">
        {/* Status da API */}
        <section className="content-section">
          <div className="section-header">
            <Bot size={20} />
            <h2 className="section-title">Status da API</h2>
          </div>
          
          {apiStatus && (
            <div className={`api-status ${apiStatus.status}`}>
              <div className="status-indicator">
                {apiStatus.status === 'ok' ? '✅' : '❌'}
              </div>
              <div className="status-details">
                <div className="status-label">Status: {apiStatus.status}</div>
                <div className="status-info">Modelo: {apiStatus.model}</div>
                <div className="status-info">Versão: {apiStatus.version}</div>
              </div>
            </div>
          )}
        </section>
        
        {/* Configuração de Telefone */}
        <section className="content-section">
          <div className="section-header">
            <Phone size={20} />
            <h2 className="section-title">Identificação</h2>
          </div>
          
          {!isMaster && (
            <div className="info-banner">
              <Shield size={16} />
              <span>
                As configurações de Tenant ID e Inbox ID são gerenciadas pelo administrador do sistema.
              </span>
            </div>
          )}
          
          {isMaster && (
            <div className="info-banner info-banner-warning">
              <Shield size={16} />
              <span>
                Como Master, você pode configurar manualmente o Tenant ID e Inbox ID para simular diferentes contextos.
              </span>
            </div>
          )}
          
          <div className="setting-item">
            <div className="setting-info">
              <label className="setting-label">
                Tenant ID
                {!isMaster && <span className="setting-badge">Bloqueado</span>}
              </label>
              <p className="setting-description">
                Identificador do tenant (cliente/empresa)
              </p>
            </div>
            <input
              type="text"
              className={`setting-input ${!isMaster ? 'setting-input-disabled' : ''}`}
              value={isMaster ? (settings.tenantId || '') : (user?.tenant_id || 'N/A')}
              onChange={(e) => isMaster && handleChange('tenantId', e.target.value)}
              placeholder="1"
              disabled={!isMaster}
              title={!isMaster ? 'Configurado automaticamente pelo sistema' : ''}
            />
          </div>
          
          <div className="setting-item">
            <div className="setting-info">
              <label className="setting-label">
                Inbox ID
                {!isMaster && <span className="setting-badge">Bloqueado</span>}
              </label>
              <p className="setting-description">
                Identificador da caixa de entrada (canal de atendimento)
              </p>
            </div>
            <input
              type="text"
              className={`setting-input ${!isMaster ? 'setting-input-disabled' : ''}`}
              value={isMaster ? (settings.inboxId || '') : (user?.inbox_id || 'N/A')}
              onChange={(e) => isMaster && handleChange('inboxId', e.target.value)}
              placeholder="27"
              disabled={!isMaster}
              title={!isMaster ? 'Configurado automaticamente pelo sistema' : ''}
            />
          </div>
          
          <div className="setting-item">
            <div className="setting-info">
              <label className="setting-label">Telefone (E.164)</label>
              <p className="setting-description">
                Número de telefone usado para identificação no CRM
                <br />
                <small>Formato: +55 (DDD) 9XXXX-XXXX</small>
              </p>
            </div>
            <input
              type="text"
              className="setting-input"
              value={phone || ''}
              onChange={handlePhoneChange}
              placeholder="+5524974023279"
            />
          </div>
          
          {phone && getPhoneValidationStatus() && (
            <div className={`validation-message ${getPhoneValidationStatus().isValid ? 'valid' : 'warning'}`}>
              {getPhoneValidationStatus().message}
            </div>
          )}
        </section>

        {/* Aparência */}
        <section className="content-section">
          <div className="section-header">
            <Palette size={20} />
            <h2 className="section-title">Aparência</h2>
          </div>
          
          <div className="setting-item">
            <div className="setting-info">
              <label className="setting-label">Tema</label>
              <p className="setting-description">Escolha entre tema claro ou escuro</p>
            </div>
            <div className="theme-selector">
              <button
                className={`theme-option ${theme === 'light' ? 'active' : ''}`}
                onClick={() => onThemeChange('light')}
              >
                ☀️ Claro
              </button>
              <button
                className={`theme-option ${theme === 'dark' ? 'active' : ''}`}
                onClick={() => onThemeChange('dark')}
              >
                🌙 Escuro
              </button>
            </div>
          </div>

          <div className="setting-item">
            <div className="setting-info">
              <label className="setting-label">Animações</label>
              <p className="setting-description">Ativar ou desativar animações da interface</p>
            </div>
            <label className="toggle-switch">
              <input
                type="checkbox"
                checked={settings.animations}
                onChange={(e) => handleChange('animations', e.target.checked)}
              />
              <span className="toggle-slider"></span>
            </label>
          </div>
        </section>

        {/* Modelo de IA */}
        <section className="content-section">
          <div className="section-header">
            <Bot size={20} />
            <h2 className="section-title">Modelo de IA</h2>
          </div>
          
          <div className="setting-item">
            <div className="setting-info">
              <label className="setting-label">Modelo</label>
              <p className="setting-description">Modelo usado pelo agente (somente leitura)</p>
            </div>
            <select
              className="setting-select"
              value={settings.aiModel}
              onChange={(e) => handleChange('aiModel', e.target.value)}
              disabled
            >
              {aiModels.map((model) => (
                <option key={model.id} value={model.id}>
                  {model.name} - {model.description}
                </option>
              ))}
            </select>
          </div>

          <div className="setting-item">
            <div className="setting-info">
              <label className="setting-label">Temperatura</label>
              <p className="setting-description">
                Controla a criatividade das respostas (0.0 - 1.0)
              </p>
            </div>
            <div className="temperature-control">
              <Thermometer size={16} />
              <input
                type="range"
                min="0"
                max="1"
                step="0.1"
                value={settings.temperature}
                onChange={(e) => handleChange('temperature', parseFloat(e.target.value))}
                className="temperature-slider"
              />
              <span className="temperature-value">{settings.temperature}</span>
            </div>
          </div>
        </section>

        {/* Comportamento */}
        <section className="content-section">
          <div className="section-header">
            <Volume2 size={20} />
            <h2 className="section-title">Comportamento</h2>
          </div>
          
          <div className="setting-item">
            <div className="setting-info">
              <label className="setting-label">Sons</label>
              <p className="setting-description">Reproduzir sons para notificações</p>
            </div>
            <label className="toggle-switch">
              <input
                type="checkbox"
                checked={settings.soundEnabled}
                onChange={(e) => handleChange('soundEnabled', e.target.checked)}
              />
              <span className="toggle-slider"></span>
            </label>
          </div>

          <div className="setting-item">
            <div className="setting-info">
              <label className="setting-label">Auto-salvar conversas</label>
              <p className="setting-description">Salvar automaticamente o histórico de conversas</p>
            </div>
            <label className="toggle-switch">
              <input
                type="checkbox"
                checked={settings.autoSave}
                onChange={(e) => handleChange('autoSave', e.target.checked)}
              />
              <span className="toggle-slider"></span>
            </label>
          </div>
        </section>

        {/* Idioma e Região */}
        <section className="content-section">
          <div className="section-header">
            <Globe size={20} />
            <h2 className="section-title">Idioma e Região</h2>
          </div>
          
          <div className="setting-item">
            <div className="setting-info">
              <label className="setting-label">Idioma</label>
              <p className="setting-description">Idioma da interface do usuário</p>
            </div>
            <select
              className="setting-select"
              value={settings.language}
              onChange={(e) => handleChange('language', e.target.value)}
            >
              {languages.map((lang) => (
                <option key={lang.id} value={lang.id}>
                  {lang.name}
                </option>
              ))}
            </select>
          </div>
        </section>

        {/* Privacidade */}
        <section className="content-section">
          <div className="section-header">
            <Shield size={20} />
            <h2 className="section-title">Privacidade</h2>
          </div>
          
          <div className="setting-item">
            <div className="setting-info">
              <label className="setting-label">Armazenar conversas localmente</label>
              <p className="setting-description">Manter o histórico de conversas no navegador</p>
            </div>
            <label className="toggle-switch">
              <input
                type="checkbox"
                checked={settings.storeLocally}
                onChange={(e) => handleChange('storeLocally', e.target.checked)}
              />
              <span className="toggle-slider"></span>
            </label>
          </div>
        </section>
        
        {/* Capacidades do Agente */}
        {agentConfig && (
          <section className="content-section">
            <div className="section-header">
              <Bot size={20} />
              <h2 className="section-title">Capacidades do Agente SDR</h2>
            </div>
            
            <div className="capabilities-list">
              {agentConfig.capabilities?.SDR?.map((cap, idx) => (
                <div key={idx} className="capability-item">
                  • {cap}
                </div>
              ))}
            </div>
          </section>
        )}
      </div>
    </div>
  );
};

export default SettingsPanel;