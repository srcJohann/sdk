import React, { useState } from 'react';
import { Search, MessageSquare, Trash2, Clock } from 'lucide-react';
import './ConversationHistory.css';

const ConversationHistory = ({ conversations, onSelectConversation, onDeleteConversation, currentUser }) => {
  const [searchTerm, setSearchTerm] = useState('');

  // If the current user is a tenant user (not MASTER), show only conversations for their tenant
  const filteredConversations = conversations
    .filter(conv => {
      if (!currentUser) return true;
      if (currentUser.role === 'MASTER') return true;
      // conv.tenantId should be set when saving conversations; if absent, be conservative and hide
      return conv.tenantId ? String(conv.tenantId) === String(currentUser.tenant_id) : false;
    })
    .filter(conv =>
      (conv.title || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (conv.messages || []).some(msg => (msg.text || '').toLowerCase().includes(searchTerm.toLowerCase()))
    );

  const formatDate = (date) => {
    const now = new Date();
    const convDate = new Date(date);
    const diffTime = Math.abs(now - convDate);
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

    if (diffDays === 1) return 'Hoje';
    if (diffDays === 2) return 'Ontem';
    if (diffDays <= 7) return `${diffDays} dias atrás`;
    
    return convDate.toLocaleDateString('pt-BR', { 
      day: '2-digit', 
      month: '2-digit', 
      year: 'numeric' 
    });
  };

  const getConversationPreview = (messages) => {
    if (!messages || messages.length === 0) return 'Nova conversa';
    const lastUserMessage = messages.filter(msg => msg.sender === 'user').slice(-1)[0];
    if (!lastUserMessage) return 'Nova conversa';
    const preview = lastUserMessage.text || '';
    return preview.length > 100 ? preview.substring(0, 100) + '...' : preview;
  };

  const getConversationTitle = (conversation) => {
    // Prefer explicit title if provided and meaningful
    if (conversation.title && typeof conversation.title === 'string') {
      const t = conversation.title.trim();
      // Avoid titles that contain 'undefined' artifacts
      if (t && !t.toLowerCase().includes('undefined')) {
        return `${t} (${conversation.agent_type || 'SDK'})`;
      }
    }

    // Otherwise use conversation id + agent type
    if (conversation.id) {
      return `${conversation.id} (${conversation.agent_type || 'SDK'})`;
    }

    // Fallback to date-based label
    return `Conversa ${new Date(conversation.updatedAt || conversation.createdAt || Date.now()).toLocaleDateString('pt-BR')}`;
  };

  return (
    <div className="page-container">
      <div className="page-header">
        <h1 className="page-title">
          <Clock size={24} />
          Histórico de Conversas
        </h1>
        <div className="search-container">
          <Search size={20} className="search-icon" />
          <input
            type="text"
            placeholder="Buscar conversas..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="search-input"
          />
        </div>
      </div>

      <div className="page-content">
        {filteredConversations.length === 0 ? (
          <div className="empty-state">
            <MessageSquare size={48} />
            <h3>Nenhuma conversa encontrada</h3>
            <p>
              {conversations.length === 0 
                ? 'Suas conversas aparecerão aqui quando você começar a usar o chat.'
                : 'Tente usar termos de busca diferentes.'
              }
            </p>
          </div>
        ) : (
          <div className="conversations-list">
            {filteredConversations.map((conversation) => (
              <div
                key={conversation.id}
                className="conversation-item"
                onClick={() => onSelectConversation(conversation)}
              >
                <div className="conversation-content">
                  <div className="conversation-header">
                    <h3 className="conversation-title">{getConversationTitle(conversation)}</h3>
                    <span className="conversation-date">
                      {formatDate(conversation.updatedAt || conversation.createdAt || Date.now())}
                    </span>
                  </div>
                  <p className="conversation-preview">
                    {getConversationPreview(conversation.messages)}
                  </p>
                  <div className="conversation-stats">
                    <span className="message-count">
                      {(conversation.messages && conversation.messages.length) || 0} mensagens
                    </span>
                  </div>
                </div>
                <button
                  className="delete-btn"
                  onClick={(e) => {
                    e.stopPropagation();
                    onDeleteConversation(conversation.id);
                  }}
                  title="Excluir conversa"
                >
                  <Trash2 size={16} />
                </button>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

export default ConversationHistory;