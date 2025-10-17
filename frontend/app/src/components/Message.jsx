import React from 'react';
import { marked } from 'marked';
import './Message.css';

// Configurar marked para links seguros
marked.setOptions({
  breaks: true,
  gfm: true,
});

const Message = ({ message }) => {
  const { text, sender, timestamp, metadata } = message;
  const isAI = sender === 'ai';
  const isSystem = sender === 'system';
  const isUser = sender === 'user';

  // Debug
  if (isUser) {
    console.log('👤 Renderizando mensagem do usuário:', text);
  }

  const formatTime = (date) => {
    return new Date(date).toLocaleTimeString('pt-BR', {
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  // Processar links do Calendly e outros
  const processLinks = (htmlContent) => {
    return htmlContent.replace(
      /(https?:\/\/[^\s<]+)/g,
      '<a href="$1" target="_blank" rel="noopener noreferrer" class="message-link">$1</a>'
    );
  };

  const renderMessageContent = () => {
    let htmlContent = marked.parse(text || '');
    htmlContent = processLinks(htmlContent);
    
    return (
      <div
        className="message-text"
        dangerouslySetInnerHTML={{ __html: htmlContent }}
      />
    );
  };

  const renderToolCalls = () => {
    if (!metadata?.tool_calls || metadata.tool_calls.length === 0) {
      return null;
    }

    return (
      <>
        <div className="ai-message-output-separator"></div>
        <div className="tool-calls-container">
          <div className="tool-calls-label">🔧 Ferramentas utilizadas</div>
          <div className="tool-calls-list">
            {metadata.tool_calls.map((tool, idx) => (
              <span key={idx} className="tool-call-badge">
                {tool}
              </span>
            ))}
          </div>
        </div>
      </>
    );
  };

  const renderRAGContext = () => {
    if (!metadata?.rag_context || metadata.rag_context.length === 0) {
      return null;
    }

    return (
      <>
        {!metadata?.tool_calls?.length && <div className="ai-message-output-separator"></div>}
        <details className="rag-context-details">
          <summary className="rag-context-summary">
            📚 Contexto usado ({metadata.rag_context.length} documento{metadata.rag_context.length > 1 ? 's' : ''})
          </summary>
          <div className="rag-context-list">
            {metadata.rag_context.map((ctx, idx) => (
              <div key={idx} className="rag-context-item">
                <div className="rag-context-score">
                  Relevância: {(ctx.score * 100).toFixed(0)}%
                </div>
                <div className="rag-context-snippet">{ctx.snippet}</div>
                {ctx.source && (
                  <div className="rag-context-source">Fonte: {ctx.source}</div>
                )}
              </div>
            ))}
          </div>
        </details>
      </>
    );
  };

  return (
    <div className={`message ${isAI ? 'ai-message' : isSystem ? 'system-message' : 'user-message'}`}>
      <div className="message-bubble">
        <div className="message-body">
          {renderMessageContent()}
          {isUser && (
            <span className="message-timestamp-inline">{formatTime(timestamp)}</span>
          )}
          {isAI && renderToolCalls()}
          {isAI && renderRAGContext()}
        </div>
        {!isUser && (
          <div className="message-meta">
            <span className="message-timestamp">{formatTime(timestamp)}</span>
            {metadata?.latency_ms && (
              <span className="message-latency">⚡ {metadata.latency_ms}ms</span>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default Message;