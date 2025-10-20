/**
 * Unified App with Role-based UI
 * 
 * Rota base: http://localhost:5173/
 * Diferenciação automática por role (MASTER, TENANT_ADMIN, TENANT_USER)
 */
import React, { useState, useEffect } from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import MainLayout from './components/Layout/MainLayout';
import ChatContainer from './components/ChatContainer';
import ConversationHistory from './components/History/ConversationHistory';
import SettingsPanel from './components/Settings/SettingsPanel';
import UserProfile from './components/Profile/UserProfile';
import MetricsPanel from './components/Debug/MetricsPanel';
import LoginPage from './components/Auth/LoginPage';

// Master-specific views
import UsersManagement from './components/Master/UsersManagement';
import TenantsManagement from './components/Master/TenantsManagement';
import InboxesManagement from './components/Master/InboxesManagement';
import AgentConfiguration from './components/Master/AgentConfiguration';
import MasterMetricsDashboard from './components/Master/MasterMetricsDashboard';

// Tenant Admin views
import TenantUsersManagement from './components/TenantAdmin/TenantUsersManagement';
import TenantInboxesView from './components/TenantAdmin/TenantInboxesView';

import MasterSidebar from './components/Layout/MasterSidebar';
import useLocalStorage from './hooks/useLocalStorage';
import useChatWithAgent from './hooks/useChatWithAgent';
import { useAuth } from './contexts/AuthContext';
import apiService from './services/dom360ApiService';
import './App.css';

function App() {
  const { isAuthenticated, user, isLoading: authLoading, isMaster, isTenantAdmin, login, logout } = useAuth();
  
  const [activeView, setActiveView] = useState('chat');
  
  // Carregar settings primeiro (antes de calcular tenantId/inboxId)
  const [theme, setTheme] = useLocalStorage('chat-theme', 'dark');
  const [settings, setSettings] = useLocalStorage('chat-settings', {
    animations: true,
    aiModel: 'amazon.nova-lite-v1:0',
    temperature: 0.2,
    soundEnabled: false,
    autoSave: true,
    language: 'pt-BR',
    storeLocally: true,
    tenantId: user?.tenant_id || '1',
    inboxId: '27',
    agentType: 'SDR',
    phone: user?.phone || '+5511999999999',
  });
  
  // Configurações do sistema
  // Master usa valores das configurações, outros usuários usam valores do user object
  const tenantId = isMaster ? settings.tenantId : (user?.tenant_id || '1');
  // Tenants must receive an inbox assigned by Master; do NOT fallback to a global default for tenant users
  const inboxId = isMaster ? settings.inboxId : (user?.inbox_id || null);
  const userPhone = settings.phone || '+5511999999999';
  const userName = user?.name || 'Usuário';
  
  // Hook de chat
  const {
    messages: backendMessages,
    conversationId,
    isLoading,
    error: chatError,
    sendMessage: sendMessageToBackend,
    loadConversation,
    switchAgent,
    clearMessages
  } = useChatWithAgent(tenantId, inboxId, userPhone);
  
  const currentMessages = React.useMemo(() => {
    return backendMessages.map(msg => ({
      id: msg.message_id || msg.id,
      text: msg.content,
      sender: msg.role === 'user' ? 'user' : msg.role === 'assistant' ? 'ai' : 'system',
      timestamp: msg.created_at,
      metadata: msg.metadata || {}
    }));
  }, [backendMessages]);
  
  const [metrics, setMetrics] = useState({
    messageCount: 0,
    totalTokens: 0,
    totalLatency: 0,
  });
  
  const [conversations, setConversations] = useLocalStorage('chat-conversations', []);

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
  }, [theme]);
  
  // Reinitialize apiService when Master changes tenant/inbox settings
  useEffect(() => {
    if (isMaster && settings.tenantId && settings.inboxId) {
      apiService.initialize(settings.tenantId, settings.inboxId);
      console.log(`🔄 API Service reinitialized for Master: tenant=${settings.tenantId}, inbox=${settings.inboxId}`);
    }
  }, [isMaster, settings.tenantId, settings.inboxId]);

  useEffect(() => {
    if (settings.autoSave && currentMessages.length > 1 && conversationId) {
      saveCurrentConversation();
    }
    if (currentMessages.length > 0) {
      setMetrics(prev => ({ ...prev, messageCount: currentMessages.length }));
    }
  }, [currentMessages, settings.autoSave, conversationId]);
  
  useEffect(() => {
    if (settings.agentType) {
      switchAgent(settings.agentType);
    }
  }, [settings.agentType]);

  const handleSendMessage = async (messageText) => {
    await sendMessageToBackend(messageText, userName);
  };

  const saveCurrentConversation = () => {
    if (currentMessages.length <= 1) return;
    // Build a safe title from the last user message (currentMessages use 'sender' and 'text')
    const lastUserMsg = currentMessages.slice().reverse().find(m => m.sender === 'user');
    let conversationTitle = 'Nova conversa';
    if (lastUserMsg && lastUserMsg.text) {
      const txt = String(lastUserMsg.text || '').trim();
      conversationTitle = txt.length > 50 ? txt.substring(0, 50) + '...' : (txt || 'Nova conversa');
    }
    const conversation = {
      id: conversationId,
      title: conversationTitle,
      messages: currentMessages,
      phone: userPhone,
      metrics: metrics,
      tenantId: tenantId,
      inboxId: inboxId,
      createdAt: conversations.find(c => c.id === conversationId)?.createdAt || new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    setConversations(prev => {
      const existing = prev.findIndex(c => c.id === conversation.id);
      if (existing !== -1) {
        const updated = [...prev];
        updated[existing] = conversation;
        return updated;
      }
      return [conversation, ...prev];
    });
  };

  const handleNewChat = () => {
    if (currentMessages.length > 1) saveCurrentConversation();
    clearMessages();
    setActiveView('chat');
  };

  const handleSelectConversation = (conversation) => {
    if (currentMessages.length > 1) saveCurrentConversation();
    // conversation may be an object from the conversation list; pass its id to the loader
    loadConversation(conversation && conversation.id ? conversation.id : conversation);
    setActiveView('chat');
  };

  const handleDeleteConversation = (conversationId) => {
    setConversations(prev => prev.filter(c => c.id !== conversationId));
  };

  const getUserStats = () => ({
    totalConversations: conversations.length,
    totalMessages: metrics.messageCount,
    totalTokens: metrics.totalTokens,
    totalLatency: metrics.totalLatency,
    timeSpent: new Date(metrics.totalLatency).toISOString().substr(11, 8),
    favoriteModel: settings.aiModel,
    averageLatency: metrics.messageCount > 0 
      ? Math.round(metrics.totalLatency / metrics.messageCount) + 'ms'
      : '0ms',
    currentPhone: userPhone || 'Não configurado',
    agentType: settings.agentType || 'SDR',
  });

  const handleLogout = () => {
    if (currentMessages.length > 1) saveCurrentConversation();
    logout();
    clearMessages();
    setActiveView('chat');
  };

  if (authLoading) {
    return (
      <div className="app-loading">
        <div className="loading-spinner"></div>
        <p>Carregando...</p>
      </div>
    );
  }

  if (!isAuthenticated) {
    return (
      <Routes>
        <Route path="*" element={<LoginPage onLogin={login} />} />
      </Routes>
    );
  }

  const renderCurrentView = () => {
    const lastAIMessage = [...currentMessages].reverse().find(msg => msg.role === 'agent');

    switch (activeView) {
      case 'chat':
        return (
          <>
            <ChatContainer 
              messages={currentMessages}
              onSendMessage={handleSendMessage}
              isLoading={isLoading}
              theme={theme}
              onToggleTheme={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
              agentType={settings.agentType || 'SDR'}
            />
            {chatError && <div className="error-banner">⚠️ {chatError}</div>}
          </>
        );
      
      case 'metrics':
        return <MetricsPanel metrics={metrics} lastMessage={lastAIMessage} settings={settings} />;
      
      case 'history':
        return (
          <ConversationHistory 
            conversations={conversations}
                onSelectConversation={handleSelectConversation}
                onDeleteConversation={handleDeleteConversation}
                currentUser={user}
          />
        );
      
      case 'settings':
        return (
          <SettingsPanel 
            settings={settings}
            onSettingsChange={setSettings}
            theme={theme}
            onThemeChange={setTheme}
            phone={userPhone}
            onPhoneChange={(newPhone) => setSettings(prev => ({ ...prev, phone: newPhone }))}
          />
        );
      
      case 'profile':
        return <UserProfile userStats={getUserStats()} />;
      
      // Master-only views
      case 'users':
        return isMaster ? <UsersManagement /> : <Navigate to="/" />;
      
      case 'tenants':
        return isMaster ? <TenantsManagement /> : <Navigate to="/" />;
      
      case 'inboxes':
        return isMaster ? <InboxesManagement /> : <Navigate to="/" />;
      
      case 'agent-config':
        return isMaster ? <AgentConfiguration /> : <Navigate to="/" />;
      
      case 'master-metrics':
        return isMaster ? <MasterMetricsDashboard /> : <Navigate to="/" />;
      
      // Tenant Admin views
      case 'tenant-users':
        return isTenantAdmin ? <TenantUsersManagement /> : <Navigate to="/" />;
      
      case 'tenant-inboxes':
        return isTenantAdmin ? <TenantInboxesView /> : <Navigate to="/" />;
      
      default:
        return null;
    }
  };

  return (
    <div className="app">
      <div className="main-layout">
        <MasterSidebar
          activeView={activeView}
          onViewChange={setActiveView}
          onNewChat={handleNewChat}
          onLogout={handleLogout}
          conversations={
            user && user.role !== 'MASTER'
              ? conversations.filter(c => c.tenantId && String(c.tenantId) === String(user.tenant_id))
              : conversations
          }
        />
        <main className="main-content">
          {renderCurrentView()}
        </main>
      </div>
    </div>
  );
}

export default App;
