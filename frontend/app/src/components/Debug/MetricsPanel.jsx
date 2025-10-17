import React, { useState } from 'react';
import { BarChart3, MessageSquare, Clock, Inbox, TrendingUp, Package, Search } from 'lucide-react';
import {
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  Area,
  AreaChart
} from 'recharts';
import './MetricsPanel.css';

const MetricsPanel = ({ metrics, lastMessage, settings }) => {
  const [selectedInbox, setSelectedInbox] = useState('all');
  
  const safeMetrics = metrics && typeof metrics === 'object' ? metrics : {
    byInbox: {},
    totalTokens: 0,
    totalLatency: 0,
    messageCount: 0,
    firstUse: new Date().toISOString()
  };
  
  const formatTime = (ms) => {
    if (ms < 1000) return `${ms}ms`;
    return `${(ms / 1000).toFixed(2)}s`;
  };

  const formatNumber = (num) => {
    return new Intl.NumberFormat('pt-BR').format(num || 0);
  };
  
  const formatDate = (dateStr) => {
    const [year, month, day] = dateStr.split('-');
    return `${day}/${month}`;
  };

  const avgLatency = safeMetrics.messageCount > 0 
    ? Math.round(safeMetrics.totalLatency / safeMetrics.messageCount)
    : 0;

  const inboxes = Object.keys(safeMetrics.byInbox || {});
  const currentInboxId = settings?.inboxId || '27';
  
  const allDates = new Set();
  Object.values(safeMetrics.byInbox || {}).forEach(inbox => {
    Object.keys(inbox.byDay || {}).forEach(date => allDates.add(date));
  });
  
  const sortedDates = Array.from(allDates).sort();
  
  const chartData = sortedDates.map(date => {
    const dayData = { 
      date: formatDate(date),
      fullDate: date
    };
    
    inboxes.forEach(inboxId => {
      const metrics = safeMetrics.byInbox[inboxId]?.byDay?.[date];
      if (metrics) {
        dayData[`inbox_${inboxId}_total`] = metrics.total_tokens;
        dayData[`inbox_${inboxId}_input`] = metrics.input_tokens;
        dayData[`inbox_${inboxId}_output`] = metrics.output_tokens;
        dayData[`inbox_${inboxId}_cached`] = metrics.cached_tokens;
      }
    });
    
    return dayData;
  });
  
  const inboxColors = {
    total: ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899']
  };
  
  const getInboxColor = (inboxId, type = 'total', index) => {
    const colorArray = inboxColors[type] || inboxColors.total;
    return colorArray[index % colorArray.length];
  };
  
  const inboxTotals = {};
  inboxes.forEach(inboxId => {
    const inbox = safeMetrics.byInbox[inboxId];
    const totals = {
      input_tokens: 0,
      output_tokens: 0,
      cached_tokens: 0,
      total_tokens: 0,
      latency: 0,
      count: 0
    };
    
    Object.values(inbox?.byDay || {}).forEach(day => {
      totals.input_tokens += day.input_tokens || 0;
      totals.output_tokens += day.output_tokens || 0;
      totals.cached_tokens += day.cached_tokens || 0;
      totals.total_tokens += day.total_tokens || 0;
      totals.latency += day.latency || 0;
      totals.count += day.count || 0;
    });
    
    inboxTotals[inboxId] = totals;
  });

  const filteredInboxes = selectedInbox === 'all' ? inboxes : [selectedInbox];

  const CustomTooltip = ({ active, payload, label }) => {
    if (active && payload && payload.length) {
      return (
        <div className="custom-tooltip">
          <p className="tooltip-label">{label}</p>
          {payload.map((entry, index) => (
            <p key={index} style={{ color: entry.color }}>
              {entry.name}: {formatNumber(entry.value)} tokens
            </p>
          ))}
        </div>
      );
    }
    return null;
  };

  const renderChart = () => {
    if (chartData.length === 0) return null;

    return (
      <ResponsiveContainer width="100%" height={400}>
        <AreaChart data={chartData} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
          <defs>
            {filteredInboxes.map((inboxId, idx) => (
              <linearGradient key={inboxId} id={`color_${inboxId}`} x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor={getInboxColor(inboxId, 'total', idx)} stopOpacity={0.8}/>
                <stop offset="95%" stopColor={getInboxColor(inboxId, 'total', idx)} stopOpacity={0.1}/>
              </linearGradient>
            ))}
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke="var(--border-color)" opacity={0.3} />
          <XAxis dataKey="date" stroke="var(--text-secondary)" style={{ fontSize: '0.75rem' }} />
          <YAxis stroke="var(--text-secondary)" style={{ fontSize: '0.75rem' }} tickFormatter={formatNumber} />
          <Tooltip content={<CustomTooltip />} />
          <Legend wrapperStyle={{ fontSize: '0.75rem' }} />
          {filteredInboxes.map((inboxId, idx) => (
            <Area key={inboxId} type="monotone" dataKey={`inbox_${inboxId}_total`} name={`Inbox ${inboxId}`} stroke={getInboxColor(inboxId, 'total', idx)} strokeWidth={2} fill={`url(#color_${inboxId})`} />
          ))}
        </AreaChart>
      </ResponsiveContainer>
    );
  };

  return (
    <div className="page-container">
      <div className="page-header">
        <h1 className="page-title">
          <BarChart3 size={24} />
          Métricas da Sessão
        </h1>
        <p className="page-subtitle">
          Acompanhe o desempenho e uso de tokens do agente SDR
        </p>
      </div>

      <div className="page-content page-content-centered">
        {/* Summary Cards */}
        <div className="cards-grid metrics-summary">
          <div className="info-card metric-card">
            <div className="metric-label">Total de Tokens</div>
            <div className="metric-value">{formatNumber(safeMetrics.totalTokens)}</div>
          </div>
          
          <div className="info-card metric-card">
            <div className="metric-label">Mensagens</div>
            <div className="metric-value">{safeMetrics.messageCount}</div>
          </div>
          
          <div className="info-card metric-card">
            <div className="metric-label">Latência Média</div>
            <div className="metric-value">{formatTime(avgLatency)}</div>
          </div>
          
          <div className="info-card metric-card">
            <div className="metric-label">Inboxes Ativas</div>
            <div className="metric-value">{inboxes.length}</div>
            <div className="metric-sublabel">Inbox atual: {currentInboxId}</div>
          </div>
        </div>

        {/* Chart Section */}
        {chartData.length > 0 && (
          <div className="content-section">
            <div className="section-header">
              <TrendingUp size={20} />
              <h2 className="section-title">Consumo de Tokens por Dia</h2>
              
              {inboxes.length > 1 && (
                <div className="chart-controls">
                  <label>Inbox: </label>
                  <select value={selectedInbox} onChange={(e) => setSelectedInbox(e.target.value)} className="control-select">
                    <option value="all">Todas</option>
                    {inboxes.map(inboxId => (<option key={inboxId} value={inboxId}>Inbox {inboxId}</option>))}
                  </select>
                </div>
              )}
            </div>
            
            <div className="chart-container">
              {renderChart()}
            </div>
          </div>
        )}

        {/* Inbox Summary */}
        {inboxes.length > 0 && (
          <div className="content-section">
            <div className="section-header">
              <Package size={20} />
              <h2 className="section-title">Resumo por Inbox</h2>
            </div>
            
            <div className="inbox-cards">
              {inboxes.map((inboxId, idx) => {
                const totals = inboxTotals[inboxId];
                return (
                  <div key={inboxId} className="inbox-card" style={{ borderLeftColor: getInboxColor(inboxId, 'total', idx) }}>
                    <div className="inbox-card-header">
                      <span className="inbox-card-title">Inbox {inboxId}</span>
                      {inboxId === currentInboxId && <span className="current-badge">Atual</span>}
                    </div>
                    <div className="inbox-card-stats">
                      <div className="label-value-pair">
                        <span className="label-text">Total Tokens:</span>
                        <span className="value-text">{formatNumber(totals.total_tokens)}</span>
                      </div>
                      <div className="label-value-pair">
                        <span className="label-text">Input:</span>
                        <span className="value-text">{formatNumber(totals.input_tokens)}</span>
                      </div>
                      <div className="label-value-pair">
                        <span className="label-text">Output:</span>
                        <span className="value-text">{formatNumber(totals.output_tokens)}</span>
                      </div>
                      <div className="label-value-pair">
                        <span className="label-text">Cached:</span>
                        <span className="value-text">{formatNumber(totals.cached_tokens)}</span>
                      </div>
                      <div className="label-value-pair">
                        <span className="label-text">Mensagens:</span>
                        <span className="value-text">{totals.count}</span>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* Last Message Metadata */}
        {lastMessage?.metadata && (
          <div className="content-section">
            <div className="section-header">
              <Search size={20} />
              <h2 className="section-title">Última Mensagem</h2>
            </div>
            
            <div className="metadata-grid">
              <div className="label-value-pair">
                <span className="label-text">Trace ID</span>
                <span className="value-text metadata-mono">{lastMessage.metadata.trace_id}</span>
              </div>
              
              {lastMessage.metadata.usage && (
                <>
                  <div className="label-value-pair">
                    <span className="label-text">Input Tokens</span>
                    <span className="value-text">{formatNumber(lastMessage.metadata.usage.input_tokens)}</span>
                  </div>
                  
                  <div className="label-value-pair">
                    <span className="label-text">Output Tokens</span>
                    <span className="value-text">{formatNumber(lastMessage.metadata.usage.output_tokens)}</span>
                  </div>
                  
                  <div className="label-value-pair">
                    <span className="label-text">Cached Tokens</span>
                    <span className="value-text">{formatNumber(lastMessage.metadata.usage.cached_tokens)}</span>
                  </div>
                  
                  <div className="label-value-pair">
                    <span className="label-text">Modelo</span>
                    <span className="value-text metadata-mono">{lastMessage.metadata.usage.model}</span>
                  </div>
                </>
              )}
              
              <div className="label-value-pair">
                <span className="label-text">Latência</span>
                <span className="value-text">{formatTime(lastMessage.metadata.latency_ms)}</span>
              </div>
            </div>
            
            {lastMessage.metadata.tool_calls?.length > 0 && (
              <div className="tools-section">
                <span className="tools-label">Ferramentas:</span>
                <div className="tool-list">
                  {lastMessage.metadata.tool_calls.map((tool, idx) => (<span key={idx} className="tool-badge">{tool}</span>))}
                </div>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default MetricsPanel;
