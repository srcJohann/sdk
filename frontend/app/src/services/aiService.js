import axios from 'axios';
import { normalizeToE164, isValidE164 } from '../utils/phoneUtils';

// Vite usa import.meta.env ao invés de process.env
const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';

// Configuração do axios
const apiClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
    'X-Agent-API-Version': '1',
  },
});

// Interceptor para tratamento de erros
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    console.error('Erro na API:', error);
    return Promise.reject(error);
  }
);

/**
 * Gera UUID v4
 */
const generateUUID = () => {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
};

/**
 * Cria requisição no formato do protocolo
 */
const createAgentRequest = (message, phone, conversationId = null) => {
  const requestId = generateUUID();
  const timestamp = new Date().toISOString();
  
  // Normaliza telefone para E.164 (adiciona +55 se necessário)
  const phoneE164 = normalizeToE164(phone);
  
  // Log para debug
  if (phone !== phoneE164) {
    console.log(`📱 Telefone normalizado: ${phone} → ${phoneE164}`);
  }
  
  // Valida formato E.164
  if (!isValidE164(phoneE164)) {
    console.warn(`⚠️ Telefone inválido: ${phoneE164}`);
  }
  
  return {
    request_id: requestId,
    tenant: {
      tenant_id: 1,
      chatwoot_account_id: 1,
      chatwoot_account_name: "DOM360 - Frontend",
      chatwoot_host: "frontend.chatwoot.local"
    },
    routing: {
      inbox_id: 27,
      agent_type: "SDR"
    },
    message: {
      content: message,
      content_type: "text",
      created_at: timestamp,
      source_id: `FRONTEND:${requestId.substring(0, 8)}`
    },
    sender: {
      name: "Frontend User",
      phone_e164: phoneE164,
      contact_id: null,
      identifier: `${phoneE164}@frontend`
    },
    conversation: {
      id: conversationId || Date.now(),
      status: "open",
      labels: ["frontend", "debug"]
    },
    metadata: {
      hmac_verified: false,
      additional: { 
        source: "frontend",
        original_phone: phone // Mantém phone original para referência
      }
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

/**
 * Envia mensagem para o agente SDR
 * @param {string} message - Mensagem do usuário
 * @param {string} phone - Telefone em formato E.164
 * @param {number} conversationId - ID da conversa
 * @returns {Promise<Object>} Resposta completa do agente
 */
export const sendMessageToSDR = async (message, phone, conversationId = null) => {
  try {
    const requestData = createAgentRequest(message, phone, conversationId);
    
    const response = await apiClient.post('/sdr', requestData, {
      headers: {
        'X-Request-ID': requestData.request_id
      }
    });

    return response.data;
  } catch (error) {
    console.error('Erro ao enviar mensagem para SDR:', error);
    
    // Retornar erro estruturado
    return {
      error: {
        code: 'CONNECTION_ERROR',
        message: error.message || 'Erro ao conectar com o servidor',
        details: error.response?.data || {}
      }
    };
  }
};

/**
 * Verifica health da API
 * @returns {Promise<Object>} Status da API
 */
export const checkAPIHealth = async () => {
  try {
    const response = await apiClient.get('/healthz');
    return response.data;
  } catch (error) {
    return {
      status: 'error',
      error: error.message
    };
  }
};

/**
 * Obtém configuração do agente
 * @returns {Promise<Object>} Configuração do agente
 */
export const getAgentConfig = async () => {
  try {
    const response = await apiClient.get('/.well-known/agent-config');
    return response.data;
  } catch (error) {
    console.error('Erro ao obter configuração:', error);
    return null;
  }
};

/**
 * Simula webhook do Chatwoot
 * @param {Object} webhookData - Dados do webhook
 * @returns {Promise<Object>} Resposta do agente
 */
export const simulateChatwootWebhook = async (webhookData) => {
  try {
    const response = await apiClient.post('/sdr', webhookData);
    return response.data;
  } catch (error) {
    console.error('Erro ao simular webhook:', error);
    return {
      error: {
        code: 'WEBHOOK_ERROR',
        message: error.message
      }
    };
  }
};

export default {
  sendMessageToSDR,
  checkAPIHealth,
  getAgentConfig,
  simulateChatwootWebhook,
};