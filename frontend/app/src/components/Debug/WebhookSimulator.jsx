import React, { useState } from 'react';
import { simulateChatwootWebhook } from '../../services/aiService';
import './WebhookSimulator.css';

const WebhookSimulator = ({ onSimulate }) => {
  const [formData, setFormData] = useState({
    phone: '+5511999998888',
    name: 'Test User',
    message: 'Olá, gostaria de saber mais sobre automação',
    tenantId: 1,
    inboxId: 27,
    conversationId: Date.now()
  });
  
  const [isLoading, setIsLoading] = useState(false);
  const [result, setResult] = useState(null);

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const generateWebhookPayload = () => {
    return {
      request_id: `sim_${Date.now()}`,
      tenant: {
        tenant_id: parseInt(formData.tenantId),
        chatwoot_account_id: parseInt(formData.tenantId),
        chatwoot_account_name: "Simulated Account",
        chatwoot_host: "simulator.chatwoot.local"
      },
      routing: {
        inbox_id: parseInt(formData.inboxId),
        agent_type: "SDR"
      },
      message: {
        content: formData.message,
        content_type: "text",
        created_at: new Date().toISOString(),
        source_id: `SIM:${formData.conversationId}`
      },
      sender: {
        name: formData.name,
        phone_e164: formData.phone,
        contact_id: null,
        identifier: `${formData.phone}@simulator`
      },
      conversation: {
        id: parseInt(formData.conversationId),
        status: "open",
        labels: ["simulator"]
      },
      metadata: {
        hmac_verified: false,
        additional: { simulated: true }
      },
      rag_options: {
        enabled: true,
        top_k: 5,
        return_chunks: true,
        match_threshold: 0.7
      },
      calendar_booking: {
        enabled: true,
        booking_url: "https://calendly.com/dom360/diagnostico-30min"
      }
    };
  };

  const handleSimulate = async () => {
    setIsLoading(true);
    setResult(null);

    try {
      const payload = generateWebhookPayload();
      const response = await simulateChatwootWebhook(payload);
      
      setResult({
        success: !response.error,
        data: response
      });
      
      if (onSimulate && !response.error) {
        onSimulate(response);
      }
    } catch (error) {
      setResult({
        success: false,
        error: error.message
      });
    } finally {
      setIsLoading(false);
    }
  };

  const copyPayload = () => {
    const payload = generateWebhookPayload();
    navigator.clipboard.writeText(JSON.stringify(payload, null, 2));
    alert('Payload copiado para clipboard!');
  };

  return (
    <div className="webhook-simulator">
      <h3>🔧 Simulador de Webhook Chatwoot</h3>
      
      <div className="simulator-form">
        <div className="form-group">
          <label>Telefone (E.164)</label>
          <input
            type="text"
            name="phone"
            value={formData.phone}
            onChange={handleChange}
            placeholder="+5511999998888"
          />
        </div>
        
        <div className="form-group">
          <label>Nome do Contato</label>
          <input
            type="text"
            name="name"
            value={formData.name}
            onChange={handleChange}
            placeholder="João Silva"
          />
        </div>
        
        <div className="form-group">
          <label>Mensagem</label>
          <textarea
            name="message"
            value={formData.message}
            onChange={handleChange}
            rows="3"
            placeholder="Digite a mensagem a ser enviada..."
          />
        </div>
        
        <div className="form-row">
          <div className="form-group">
            <label>Tenant ID</label>
            <input
              type="number"
              name="tenantId"
              value={formData.tenantId}
              onChange={handleChange}
            />
          </div>
          
          <div className="form-group">
            <label>Inbox ID</label>
            <input
              type="number"
              name="inboxId"
              value={formData.inboxId}
              onChange={handleChange}
            />
          </div>
          
          <div className="form-group">
            <label>Conversation ID</label>
            <input
              type="number"
              name="conversationId"
              value={formData.conversationId}
              onChange={handleChange}
            />
          </div>
        </div>
        
        <div className="button-group">
          <button 
            className="btn btn-primary"
            onClick={handleSimulate}
            disabled={isLoading}
          >
            {isLoading ? '⏳ Simulando...' : '🚀 Simular Webhook'}
          </button>
          
          <button 
            className="btn btn-secondary"
            onClick={copyPayload}
          >
            📋 Copiar Payload
          </button>
        </div>
      </div>
      
      {result && (
        <div className={`result ${result.success ? 'success' : 'error'}`}>
          <h4>{result.success ? '✅ Sucesso' : '❌ Erro'}</h4>
          <pre>{JSON.stringify(result.data || result.error, null, 2)}</pre>
        </div>
      )}
    </div>
  );
};

export default WebhookSimulator;
