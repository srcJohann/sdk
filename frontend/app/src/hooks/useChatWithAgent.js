// ============================================================================
// DOM360 Frontend - Custom Hook for Chat with Agent
// ============================================================================

import { useState, useCallback, useEffect } from 'react';
import apiService from '../services/dom360ApiService';

/**
 * Custom hook for chat functionality with DOM360 agents
 */
export const useChatWithAgent = (tenantId, inboxId, userPhone) => {
    const [messages, setMessages] = useState([]);
    const [conversationId, setConversationId] = useState(null);
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState(null);
    const [agentType, setAgentType] = useState('SDR');

    // Initialize API service
    useEffect(() => {
        if (tenantId && inboxId) {
            apiService.initialize(tenantId, inboxId);
        }
    }, [tenantId, inboxId]);

    /**
     * Send message to agent
     */
    const sendMessage = useCallback(async (messageText, userName = null) => {
        if (!messageText.trim()) {
            return;
        }

        setIsLoading(true);
        setError(null);

        // Add user message to UI immediately
        const tempUserMessage = {
            id: `temp_${Date.now()}`,
            role: 'user',
            content: messageText,
            created_at: new Date().toISOString(),
            isTemp: true,
        };
        setMessages(prev => [...prev, tempUserMessage]);

        try {
            // Call API with correct parameter order
            const response = await apiService.sendMessage(
                messageText,      // message
                conversationId,   // conversationId
                agentType,        // agentType
                userPhone,        // userPhone
                userName          // userName
            );

            // Update conversation ID
            if (!conversationId) {
                setConversationId(response.conversation_id);
            }

            // Replace temp message and add assistant response
            setMessages(prev => {
                const filtered = prev.filter(m => m.id !== tempUserMessage.id);
                return [
                    ...filtered,
                    {
                        id: response.user_message.id,
                        index: response.user_message.index,
                        role: 'user',
                        content: response.user_message.content,
                        created_at: response.user_message.created_at,
                    },
                    {
                        id: response.assistant_message.id,
                        index: response.assistant_message.index,
                        role: 'assistant',
                        content: response.assistant_message.content,
                        tool_calls: response.assistant_message.tool_calls,
                        rag_context: response.assistant_message.rag_context,
                        created_at: response.assistant_message.created_at,
                    },
                ];
            });

            return response;
        } catch (err) {
            console.error('Error sending message:', err);
            setError(err.message);
            
            // Remove temp message on error
            setMessages(prev => prev.filter(m => m.id !== tempUserMessage.id));
            
            throw err;
        } finally {
            setIsLoading(false);
        }
    }, [userPhone, agentType, conversationId]);

    /**
     * Load conversation history
     */
    const loadConversation = useCallback(async (convId) => {
        setIsLoading(true);
        setError(null);
        // Accept either a conversation id string or a conversation object { id, ... }
        const conv = (convId && typeof convId === 'object') ? convId.id : convId;

        try {
            const response = await apiService.getConversationMessages(conv);
            
            // Support two possible response shapes from the API:
            // - an array of messages (legacy / current backend)
            // - an object { messages: [...] }
            const msgs = Array.isArray(response) ? response : (response && response.messages) ? response.messages : [];

            const formattedMessages = msgs.map((msg, idx) => {
                // id: support multiple names
                const id = msg.message_id || msg.id || (`msg_${idx}`);

                // index: prefer explicit message_index or index, fallback to array position
                const index = msg.message_index || msg.index || idx + 1;

                // role
                const role = msg.role || (msg.type || 'user');

                // content: prefer normalized content field, otherwise fallback to user_message/assistant_message
                const content = (typeof msg.content !== 'undefined')
                    ? msg.content
                    : (role === 'user' ? msg.user_message : msg.assistant_message) || '';

                // metadata / tooling
                const tool_calls = msg.tool_calls || (msg.metadata && msg.metadata.tool_calls) || [];
                const rag_context = msg.rag_context || (msg.metadata && msg.metadata.rag_context) || [];

                const tokens = msg.tokens || {
                    input: msg.input_tokens || 0,
                    output: msg.output_tokens || 0,
                    total: msg.total_tokens || 0
                };

                const created_at = msg.created_at || (msg.createdAt) || new Date().toISOString();

                return {
                    id,
                    index,
                    role,
                    content,
                    tool_calls,
                    rag_context,
                    tokens,
                    latency_ms: msg.latency_ms || (msg.metadata && msg.metadata.latency_ms) || 0,
                    model: msg.model_used || msg.model || null,
                    created_at,
                    metadata: msg.metadata || {}
                };
            });

            setMessages(formattedMessages);
            setConversationId(conv);
        } catch (err) {
            console.error('Error loading conversation:', err);
            setError(err.message);
            throw err;
        } finally {
            setIsLoading(false);
        }
    }, []);

    /**
     * Clear conversation
     */
    const clearConversation = useCallback(() => {
        setMessages([]);
        setConversationId(null);
        setError(null);
    }, []);

    /**
     * Switch agent type
     */
    const switchAgent = useCallback((newAgentType) => {
        if (['SDR', 'COPILOT'].includes(newAgentType)) {
            setAgentType(newAgentType);
            // Optionally clear conversation when switching agents
            clearConversation();
        }
    }, [clearConversation]);

    return {
        messages,
        conversationId,
        isLoading,
        error,
        agentType,
        sendMessage,
        loadConversation,
        clearConversation,
        // backwards-compatible alias (some callers expect clearMessages)
        clearMessages: clearConversation,
        switchAgent,
    };
};

export default useChatWithAgent;
