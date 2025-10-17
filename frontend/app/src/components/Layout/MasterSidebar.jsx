/**
 * Master Sidebar - ChatGPT-like Navigation with Role-based Features
 * 
 * Diferenciação automática:
 * - MASTER: Vê opções de gerenciamento de usuários, tenants, e configuração do agente
 * - TENANT_ADMIN: Vê opções de gerenciamento limitado ao seu tenant
 * - TENANT_USER: Vê apenas chat e suas configurações pessoais
 */
import React, { useState } from 'react';
import { 
  MessageSquare, 
  Clock, 
  Settings, 
  User, 
  Plus, 
  Activity, 
  LogOut,
  Users,
  Building2,
  Cpu,
  Shield,
  ChevronDown,
  ChevronRight,
  Inbox,
  BarChart3
} from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import logo from '../../assets/logo_dom360.png';
import './MasterSidebar.css';

const MasterSidebar = ({ activeView, onViewChange, onNewChat, onLogout, conversations }) => {
  const { user, isMaster, isTenantAdmin } = useAuth();
  // auth context exports functions; call to get boolean values
  const _isMaster = typeof isMaster === 'function' ? isMaster() : !!isMaster;
  const _isTenantAdmin = typeof isTenantAdmin === 'function' ? isTenantAdmin() : !!isTenantAdmin;
  const [expandedSections, setExpandedSections] = useState({
    management: true,
    settings: false
  });

  const toggleSection = (section) => {
    setExpandedSections(prev => ({
      ...prev,
      [section]: !prev[section]
    }));
  };

  // Menu items comum para todos
  const commonMenuItems = [
    { id: 'chat', icon: MessageSquare, label: 'Chat SDR', badge: null },
    { id: 'history', icon: Clock, label: 'Histórico', badge: conversations?.length || 0 },
    { id: 'metrics', icon: Activity, label: 'Métricas', badge: null },
  ];

  // Menu items apenas para Master
  const masterMenuItems = [
    { id: 'users', icon: Users, label: 'Gerenciar Usuários', section: 'management' },
    { id: 'tenants', icon: Building2, label: 'Gerenciar Tenants', section: 'management' },
    { id: 'inboxes', icon: Inbox, label: 'Gerenciar Inboxes', section: 'management' },
    { id: 'agent-config', icon: Cpu, label: 'Configurar Agente IA', section: 'settings' },
    { id: 'master-metrics', icon: BarChart3, label: 'Métricas Globais', section: 'settings' },
  ];

  // Menu items apenas para Tenant Admin
  const tenantAdminMenuItems = [
    { id: 'tenant-users', icon: Users, label: 'Usuários do Tenant', section: 'management' },
    { id: 'tenant-inboxes', icon: Inbox, label: 'Inboxes do Tenant', section: 'management' },
  ];

  const renderMenuItem = (item) => {
    const Icon = item.icon;
    return (
      <button
        key={item.id}
        className={`nav-item ${activeView === item.id ? 'active' : ''}`}
        onClick={() => onViewChange(item.id)}
        title={item.label}
      >
        <Icon size={18} />
        <span className="nav-label">{item.label}</span>
        {item.badge !== null && item.badge > 0 && (
          <span className="nav-badge">{item.badge}</span>
        )}
      </button>
    );
  };

  const renderSection = (title, items, sectionKey) => {
    const isExpanded = expandedSections[sectionKey];
    
    return (
      <div className="nav-section">
        <button 
          className="section-header"
          onClick={() => toggleSection(sectionKey)}
        >
          <span className="section-title">
            {isExpanded ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
            {title}
          </span>
        </button>
        {isExpanded && (
          <div className="section-items">
            {items.map(item => renderMenuItem(item))}
          </div>
        )}
      </div>
    );
  };

  return (
    <div className="master-sidebar">
      {/* Header */}
      <div className="sidebar-header">
        <div className="logo">
          <img src={logo} alt="DOM360" className="sidebar-logo-image" />
        </div>
        <button className="new-chat-btn" onClick={onNewChat} title="Nova conversa">
          <Plus size={20} />
          <span>Nova conversa</span>
        </button>
      </div>

      {/* Navigation */}
      <nav className="sidebar-nav">
        {/* Common items - sempre visíveis */}
        <div className="nav-section">
          {commonMenuItems.map(item => renderMenuItem(item))}
        </div>

        {/* Master-only sections */}
  {_isMaster && (
          <>
            {renderSection(
              'Gerenciamento Master',
              masterMenuItems.filter(item => item.section === 'management'),
              'management'
            )}
            {renderSection(
              'Configurações Avançadas',
              masterMenuItems.filter(item => item.section === 'settings'),
              'settings'
            )}
          </>
        )}

        {/* Tenant Admin-only section */}
  {_isTenantAdmin && !_isMaster && (
          <>
            {renderSection(
              'Gerenciamento do Tenant',
              tenantAdminMenuItems,
              'management'
            )}
          </>
        )}

        {/* Settings - comum para todos */}
        <div className="nav-section nav-section-bottom">
          {renderMenuItem({ id: 'settings', icon: Settings, label: 'Configurações' })}
          {renderMenuItem({ id: 'profile', icon: User, label: 'Meu Perfil' })}
        </div>
      </nav>

      {/* Footer */}
      <div className="sidebar-footer">
        {user && (
          <div className="user-info">
            <div className={`user-avatar ${String(user.role || '').toLowerCase()}`}>
              {String(user.role || '') === 'MASTER' ? <Shield size={16} /> : <User size={16} />}
            </div>
            <div className="user-details">
              <span className="user-name">{user.username}</span>
              <span className="user-role">{getRoleLabel(user.role)}</span>
            </div>
          </div>
        )}
        <button className="logout-btn" onClick={onLogout} title="Sair">
          <LogOut size={18} />
          <span>Sair</span>
        </button>
      </div>
    </div>
  );
};

const getRoleLabel = (role) => {
  const labels = {
    'MASTER': 'Administrador Global',
    'TENANT_ADMIN': 'Admin do Tenant',
    'TENANT_USER': 'Usuário'
  };
  return labels[role] || role;
};

export default MasterSidebar;
