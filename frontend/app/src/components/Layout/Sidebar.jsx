import React from 'react';
import { MessageSquare, Clock, Settings, User, Plus, Activity, LogOut } from 'lucide-react';
import logo from '../../assets/logo_dom360.png';
import './Sidebar.css';

const Sidebar = ({ activeView, onViewChange, onNewChat, onLogout, conversations, user }) => {
  const menuItems = [
    { id: 'chat', icon: MessageSquare, label: 'Chat SDR', badge: null },
    { id: 'metrics', icon: Activity, label: 'Métricas', badge: null },
    { id: 'history', icon: Clock, label: 'Histórico', badge: conversations?.length || 0 },
    { id: 'settings', icon: Settings, label: 'Configurações', badge: null },
    { id: 'profile', icon: User, label: 'Perfil', badge: null },
  ];

  return (
    <div className="sidebar">
      <div className="sidebar-header">
        <div className="logo">
          <img src={logo} alt="DOM360" className="sidebar-logo-image" />
        </div>
        <button className="new-chat-btn" onClick={onNewChat} title="Nova conversa">
          <Plus size={20} />
          <span>Nova conversa</span>
        </button>
      </div>

      <nav className="sidebar-nav">
        {menuItems.map((item) => {
          const Icon = item.icon;
          return (
            <button
              key={item.id}
              className={`nav-item ${activeView === item.id ? 'active' : ''}`}
              onClick={() => onViewChange(item.id)}
              title={item.label}
            >
              <Icon size={20} />
              <span className="nav-label">{item.label}</span>
              {item.badge !== null && item.badge > 0 && (
                <span className="nav-badge">{item.badge}</span>
              )}
            </button>
          );
        })}
      </nav>

      <div className="sidebar-footer">
        {user && (
          <div className="user-info">
            <div className="user-avatar">
              <User size={16} />
            </div>
            <div className="user-details">
              <span className="user-name">{user.username}</span>
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

export default Sidebar;