import React from 'react';
import Header from './Header';
import MessageList from './MessageList';
import MessageInput from './MessageInput';
import './ChatContainer.css';

const ChatContainer = ({ 
  messages, 
  onSendMessage, 
  isLoading, 
  theme, 
  onToggleTheme,
  error,
  agentType,
  onAgentChange
}) => {
  return (
    <div className="chat-container">
      <Header 
        theme={theme} 
        onToggleTheme={onToggleTheme}
        agentType={agentType}
        onAgentChange={onAgentChange}
      />
      <div className="chat-content">
        <MessageList messages={messages} isLoading={isLoading} error={error} />
        <MessageInput onSendMessage={onSendMessage} isLoading={isLoading} />
      </div>
    </div>
  );
};

export default ChatContainer;