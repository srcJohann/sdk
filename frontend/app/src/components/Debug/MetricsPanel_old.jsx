import React from 'react';
import './MetricsPanel.css';

const MetricsPanel = ({ metrics, lastMessage }) => {
  // Guard: garantir que metrics é um objeto válido
  const safeMetrics = metrics && typeof metrics === 'object' ? metrics : {
    totalTokens: 0,
    totalLatency: 0,
    messageCount: 0,
    sessionStart: new Date().toISOString()
  };
  
  const formatTime = (ms) => {
    if (ms < 1000) return `${ms}ms`;
    return `${(ms / 1000).toFixed(2)}s`;
  };

  const formatNumber = (num) => {
    return new Intl.NumberFormat('pt-BR').format(num || 0);
  };

  const avgLatency = safeMetrics.messageCount > 0 
    ? Math.round(safeMetrics.totalLatency / safeMetrics.messageCount)
    : 0;

  return (
    <div className="metrics-panel">
      <h3>📊 Métricas da Sessão</h3>
      
      <div className="metrics-grid">
        <div className="metric-card">
          <div className="metric-label">Total de Tokens</div>
          <div className="metric-value">{formatNumber(safeMetrics.totalTokens)}</div>
        </div>
        
        <div className="metric-card">
          <div className="metric-label">Mensagens</div>
          <div className="metric-value">{safeMetrics.messageCount}</div>
        </div>
        
        <div className="metric-card">
          <div className="metric-label">Latência Média</div>
          <div className="metric-value">{formatTime(avgLatency)}</div>
        </div>
        
        <div className="metric-card">
          <div className="metric-label">Latência Total</div>
          <div className="metric-value">{formatTime(safeMetrics.totalLatency)}</div>
        </div>
      </div>

      {lastMessage?.metadata && (
        <div className="last-message-metrics">
          <h4>🔍 Última Mensagem</h4>
          
          <div className="metadata-item">
            <span className="metadata-label">Trace ID:</span>
            <span className="metadata-value trace-id">{lastMessage.metadata.trace_id}</span>
          </div>
          
          {lastMessage.metadata.usage && (
            <>
              <div className="metadata-item">
                <span className="metadata-label">Tokens Entrada:</span>
                <span className="metadata-value">{lastMessage.metadata.usage.input_tokens}</span>
              </div>
              
              <div className="metadata-item">
                <span className="metadata-label">Tokens Saída:</span>
                <span className="metadata-value">{lastMessage.metadata.usage.output_tokens}</span>
              </div>
              
              <div className="metadata-item">
                <span className="metadata-label">Tokens Cache:</span>
                <span className="metadata-value">{lastMessage.metadata.usage.cached_tokens}</span>
              </div>
              
              <div className="metadata-item">
                <span className="metadata-label">Modelo:</span>
                <span className="metadata-value">{lastMessage.metadata.usage.model}</span>
              </div>
            </>
          )}
          
          <div className="metadata-item">
            <span className="metadata-label">Latência:</span>
            <span className="metadata-value">{formatTime(lastMessage.metadata.latency_ms)}</span>
          </div>
          
          {lastMessage.metadata.tool_calls?.length > 0 && (
            <div className="metadata-item">
              <span className="metadata-label">Ferramentas:</span>
              <div className="tool-calls">
                {lastMessage.metadata.tool_calls.map((tool, idx) => (
                  <span key={idx} className="tool-badge">{tool}</span>
                ))}
              </div>
            </div>
          )}
          
          {lastMessage.metadata.rag_context?.length > 0 && (
            <div className="metadata-item">
              <span className="metadata-label">Contexto RAG:</span>
              <div className="rag-context">
                {lastMessage.metadata.rag_context.map((ctx, idx) => (
                  <div key={idx} className="rag-item">
                    <div className="rag-score">Score: {ctx.score.toFixed(2)}</div>
                    <div className="rag-snippet">{ctx.snippet}</div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default MetricsPanel;
