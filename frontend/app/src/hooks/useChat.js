import { useState, useCallback, useEffect } from 'react';
import { sendMessageToSDR } from '../services/aiService';
import useLocalStorage from './useLocalStorage';

const useChat = () => {
  // Estado do telefone (persiste no localStorage)
  const [phone, setPhone] = useLocalStorage('sdr_phone', '');
  
  // Estado da conversa atual - NÃO usar localStorage para não perder durante a sessão
  const [conversationId] = useState(() => {
    const existingId = sessionStorage.getItem('sdr_conversation_id');
    if (existingId) return parseInt(existingId);
    const newId = Date.now();
    sessionStorage.setItem('sdr_conversation_id', newId.toString());
    return newId;
  });
  
  // Mensagens da conversa - usar useState normal e sincronizar com localStorage manualmente
  const [messages, setMessages] = useState(() => {
    try {
      const saved = window.localStorage.getItem('sdr_messages');
      return saved ? JSON.parse(saved) : [
        {
          id: 1,
          text: "Olá! Sou o Mr. DOM, assistente de SDR da DOM360. Como posso ajudar você hoje?",
          sender: 'ai',
          timestamp: new Date().toISOString()
        }
      ];
    } catch {
      return [
        {
          id: 1,
          text: "Olá! Sou o Mr. DOM, assistente de SDR da DOM360. Como posso ajudar você hoje?",
          sender: 'ai',
          timestamp: new Date().toISOString()
        }
      ];
    }
  });

  // Sincronizar mensagens com localStorage sempre que mudar
  useEffect(() => {
    try {
      console.log(`💾 [useChat] Sincronizando ${messages.length} mensagens com localStorage`);
      window.localStorage.setItem('sdr_messages', JSON.stringify(messages));
    } catch (error) {
      console.error('Erro ao salvar mensagens:', error);
    }
  }, [messages]);
  
  // Estado de carregamento e erro
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState(null);
  
  // Métricas GLOBAIS acumuladas por inbox e dia (persiste entre sessões)
  const [metrics, setMetrics] = useLocalStorage('sdr_global_metrics', {
    byInbox: {},  // { inboxId: { byDay: { "2025-01-14": { input_tokens, output_tokens, cached_tokens, total_tokens, latency, count } } } }
    totalTokens: 0,
    totalLatency: 0,
    messageCount: 0,
    firstUse: new Date().toISOString() // Data da primeira utilização
  });

  const sendMessage = useCallback(async (messageText, settings = {}) => {
    if (!messageText.trim()) return;
    
    // Validar telefone
    if (!phone || !phone.startsWith('+')) {
      setError('Configure um telefone válido em formato E.164 (ex: +5511999998888) nas configurações.');
      return;
    }
    
    // Extrair tenantId e inboxId dos settings
    const tenantId = settings.tenantId || '1';
    const inboxId = settings.inboxId || '27';

    const userMessage = {
      id: Date.now(),
      text: messageText,
      sender: 'user',
      timestamp: new Date().toISOString()
    };

    // Adicionar mensagem do usuário imediatamente
    setMessages(prev => {
      const newMessages = [...prev, userMessage];
      console.log('📤 Mensagem do usuário adicionada:', userMessage);
      console.log('📋 Total de mensagens:', newMessages.length);
      return newMessages;
    });
    
    setIsLoading(true);
    setError(null);

    try {
      // Enviar para API SDR
      const response = await sendMessageToSDR(messageText, phone, conversationId);
      
      // Verificar erro
      if (response.error) {
        throw new Error(response.error.message || 'Erro desconhecido');
      }
      
      // Criar mensagem do agente
      const aiResponse = {
        id: Date.now() + 1,
        text: response.agent_output?.text || 'Sem resposta',
        sender: 'ai',
        timestamp: new Date().toISOString(),
        metadata: {
          trace_id: response.trace_id,
          request_id: response.request_id,
          tool_calls: response.agent_output?.tool_calls || [],
          rag_context: response.agent_output?.rag_context || [],
          usage: response.usage,
          latency_ms: response.latency_ms,
          session: response.session
        }
      };

      // Adicionar resposta do agente
      setMessages(prev => {
        const newMessages = [...prev, aiResponse];
        console.log('🤖 Resposta do agente adicionada:', aiResponse);
        console.log('📋 Total de mensagens:', newMessages.length);
        return newMessages;
      });
      
      // Atualizar métricas por inbox e dia
      if (response.usage) {
        const today = new Date().toISOString().split('T')[0]; // "2025-01-14"
        
        setMetrics(prev => {
          const inboxMetrics = prev.byInbox[inboxId] || { byDay: {} };
          const dayMetrics = inboxMetrics.byDay[today] || {
            input_tokens: 0,
            output_tokens: 0,
            cached_tokens: 0,
            total_tokens: 0,
            latency: 0,
            count: 0
          };

          return {
            ...prev,
            byInbox: {
              ...prev.byInbox,
              [inboxId]: {
                byDay: {
                  ...inboxMetrics.byDay,
                  [today]: {
                    input_tokens: dayMetrics.input_tokens + (response.usage.input_tokens || 0),
                    output_tokens: dayMetrics.output_tokens + (response.usage.output_tokens || 0),
                    cached_tokens: dayMetrics.cached_tokens + (response.usage.cached_tokens || 0),
                    total_tokens: dayMetrics.total_tokens + (response.usage.total_tokens || 0),
                    latency: dayMetrics.latency + (response.latency_ms || 0),
                    count: dayMetrics.count + 1
                  }
                }
              }
            },
            totalTokens: prev.totalTokens + (response.usage.total_tokens || 0),
            totalLatency: prev.totalLatency + (response.latency_ms || 0),
            messageCount: prev.messageCount + 1
          };
        });
      }
      
    } catch (error) {
      console.error('Erro ao enviar mensagem:', error);
      setError(error.message || 'Erro ao comunicar com o assistente. Tente novamente.');
      
      // Adicionar mensagem de erro
      const errorMessage = {
        id: Date.now() + 1,
        text: `❌ Erro: ${error.message}`,
        sender: 'system',
        timestamp: new Date().toISOString()
      };
      setMessages(prev => [...prev, errorMessage]);
      
    } finally {
      setIsLoading(false);
    }
  }, [phone, conversationId, setMetrics]);

  const clearChat = useCallback(() => {
    const initialMessage = {
      id: 1,
      text: "Olá! Sou o Mr. DOM, assistente de SDR da DOM360. Como posso ajudar você hoje?",
      sender: 'ai',
      timestamp: new Date().toISOString()
    };
    
    setMessages([initialMessage]);
    // Métricas são GLOBAIS - não resetar ao limpar chat
    setError(null);
  }, []);
  
  const loadConversation = useCallback((conversation) => {
    setMessages(conversation.messages || []);
    // Métricas são GLOBAIS - não sobrescrever ao carregar conversa
    // Criar novo conversationId para esta sessão carregada
    const newConvId = Date.now();
    sessionStorage.setItem('sdr_conversation_id', newConvId.toString());
    setPhone(conversation.phone || '');
    setError(null);
  }, []);
  
  const exportHistory = useCallback(() => {
    const data = {
      phone,
      conversationId,
      messages,
      metrics,
      exportedAt: new Date().toISOString()
    };
    
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `sdr_history_${Date.now()}.json`;
    a.click();
    URL.revokeObjectURL(url);
  }, [phone, conversationId, messages, metrics]);

  return {
    messages,
    isLoading,
    error,
    phone,
    metrics,
    conversationId,
    sendMessage,
    clearChat,
    loadConversation,
    setPhone,
    exportHistory
  };
};

export default useChat;