import React, { useEffect, useRef } from 'react';
import Message from './Message';
import TypingIndicator from './TypingIndicator';
import './MessageList.css';

const MessageList = ({ messages, isLoading, error }) => {
  const messagesEndRef = useRef(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages, isLoading]);

  // Debug: log de mensagens (mantém para investigação)
  useEffect(() => {
    console.log(`📋 [MessageList] Renderizando ${messages.length} mensagens`);
    if (messages.length > 0) {
      const userMsgs = messages.filter(m => m.sender === 'user').length;
      const aiMsgs = messages.filter(m => m.sender === 'ai').length;
      console.log(`   👤 Usuário: ${userMsgs} | 🤖 IA: ${aiMsgs}`);
    }
  }, [messages]);

  if (!messages || messages.length === 0) {
    return (
      <div className="message-list">
        <div className="messages-container">
          <div className="empty-state">Nenhuma mensagem ainda</div>
        </div>
      </div>
    );
  }

  return (
    <div className="message-list">
      <div className="messages-container">
        {messages.map((message, index) => (
          <Message key={`${message.id}-${index}`} message={message} />
        ))}
        {isLoading && <TypingIndicator />}
        {error && (
          <div className="error-message">
            <span className="error-icon">⚠️</span>
            {error}
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>
    </div>
  );
};

export default MessageList;