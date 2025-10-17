/**
 * Master Metrics Dashboard
 */
import React, { useState, useEffect } from 'react';
import { getGlobalMetrics, listTenants } from '../../services/adminService';
import './MasterMetricsDashboard.css';

const MasterMetricsDashboard = () => {
  const [metrics, setMetrics] = useState(null);
  const [tenants, setTenants] = useState([]);
  const [filters, setFilters] = useState({ fromDate: '', toDate: '', tenantId: '' });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => { loadTenants(); }, []);
  useEffect(() => { loadMetrics(); }, [filters]);

  const loadTenants = async () => {
    try {
      const data = await listTenants({ limit: 200 });
      setTenants(data);
    } catch (err) {
      console.error('Error loading tenants:', err);
    }
  };

  const loadMetrics = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await getGlobalMetrics(filters);
      setMetrics(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const formatNumber = (num) => new Intl.NumberFormat('pt-BR').format(num || 0);

  if (loading) return <div className="loading-spinner"><div className="spinner"></div></div>;

  return (
    <div className="master-metrics-dashboard">
      <h1>Métricas Globais</h1>

      {/* Filters */}
      <div className="metrics-filters">
        <select value={filters.tenantId} onChange={(e) => setFilters(prev => ({ ...prev, tenantId: e.target.value }))}>
          <option value="">Todos os tenants</option>
          {tenants.map(t => <option key={t.id} value={t.id}>{t.name}</option>)}
        </select>
        <input type="date" value={filters.fromDate} onChange={(e) => setFilters(prev => ({ ...prev, fromDate: e.target.value }))} />
        <input type="date" value={filters.toDate} onChange={(e) => setFilters(prev => ({ ...prev, toDate: e.target.value }))} />
        <button onClick={() => setFilters({ fromDate: '', toDate: '', tenantId: '' })}>Limpar</button>
      </div>

      {error && <div className="alert alert-error">⚠️ {error}</div>}

      {/* Metrics Cards */}
      {metrics && (
        <div className="metrics-grid">
          <div className="metric-card">
            <div className="metric-value">{formatNumber(metrics.total_tenants)}</div>
            <div className="metric-label">Total Tenants</div>
            <div className="metric-sublabel">{formatNumber(metrics.active_tenants)} ativos</div>
          </div>
          <div className="metric-card">
            <div className="metric-value">{formatNumber(metrics.total_inboxes)}</div>
            <div className="metric-label">Total Inboxes</div>
          </div>
          <div className="metric-card">
            <div className="metric-value">{formatNumber(metrics.total_conversations)}</div>
            <div className="metric-label">Conversas</div>
          </div>
          <div className="metric-card">
            <div className="metric-value">{formatNumber(metrics.total_messages)}</div>
            <div className="metric-label">Mensagens</div>
          </div>
          <div className="metric-card">
            <div className="metric-value">{formatNumber(metrics.total_tokens)}</div>
            <div className="metric-label">Tokens Consumidos</div>
          </div>
          <div className="metric-card">
            <div className="metric-value">{formatNumber(metrics.avg_latency_ms)}ms</div>
            <div className="metric-label">Latência Média</div>
          </div>
        </div>
      )}
    </div>
  );
};

export default MasterMetricsDashboard;
