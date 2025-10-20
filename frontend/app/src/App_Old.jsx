import React, { useState, useEffect } from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import MainLayout from './components/Layout/MainLayout';
import ChatContainer from './components/ChatContainer';
import ConversationHistory from './components/History/ConversationHistory';
import SettingsPanel from './components/Settings/SettingsPanel';
import UserProfile from './components/Profile/UserProfile';
import MetricsPanel from './components/Debug/MetricsPanel';
import LoginPage from './components/Auth/LoginPage';
import AdminMasterLayout from './components/Master/AdminMasterLayout';
import useLocalStorage from './hooks/useLocalStorage';
import useChatWithAgent from './hooks/useChatWithAgent'; // ✅ Hook correto (usa backend FastAPI)
import { useAuth, MasterRoute } from './contexts/AuthContext';
import './App.css';

function App() {
  // Hook de autenticação
  const { isAuthenticated, user, isLoading: authLoading, login, logout } = useAuth();
  
  // Estado da aplicação
  const [activeView, setActiveView] = useState('chat');
  
  // Configurações do sistema (tenant, inbox, user)
  const tenantId = '1';
  const inboxId = '27';
  const userPhone = '+5511999999999';
  const userName = 'Usuário';
  
  // Hook de chat integrado com backend FastAPI ✅
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
  
  // Adaptar formato das mensagens do backend para o formato do frontend
  const currentMessages = React.useMemo(() => {
    return backendMessages.map(msg => ({
      id: msg.message_id || msg.id,
      text: msg.content,
      sender: msg.role === 'user' ? 'user' : msg.role === 'assistant' ? 'ai' : 'system',
      timestamp: msg.created_at,
      metadata: msg.metadata || {}
    }));
  }, [backendMessages]);
  
  // Configurações persistentes
  const [theme, setTheme] = useLocalStorage('chat-theme', 'dark');
  const [settings, setSettings] = useLocalStorage('chat-settings', {
    animations: true,
    aiModel: 'amazon.nova-lite-v1:0',
    temperature: 0.2,
    soundEnabled: false,
    autoSave: true,
    language: 'pt-BR',
    storeLocally: true,
    tenantId: tenantId,
    inboxId: inboxId,
    agentType: 'SDR', // SDR ou COPILOT
  });
  
  // Métricas locais (opcional - pode vir do backend depois)
  const [metrics, setMetrics] = useState({
    messageCount: 0,
    totalTokens: 0,
    totalLatency: 0,
  });
  
  // Histórico de conversas (local - futuramente buscar do backend)
  const [conversations, setConversations] = useLocalStorage('chat-conversations', []);

  // Aplicar tema ao documento
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    document.body.style.setProperty('--theme-transition', 'all 0.3s ease');
  }, [theme]);

  // Salvar conversa automaticamente
  useEffect(() => {
    if (settings.autoSave && currentMessages.length > 1 && conversationId) {
      saveCurrentConversation();
    }
    
    // Atualizar métricas
    if (currentMessages.length > 0) {
      setMetrics(prev => ({
        ...prev,
        messageCount: currentMessages.length,
      }));
    }
  }, [currentMessages, settings.autoSave, conversationId]);
  
  // Sincronizar agentType com settings
  useEffect(() => {
    if (settings.agentType) {
      switchAgent(settings.agentType);
    }
  }, [settings.agentType]);

  const handleSendMessage = async (messageText) => {
    // Usar hook integrado com backend ✅
    await sendMessageToBackend(messageText, userName);
  };

  const saveCurrentConversation = () => {
    if (currentMessages.length <= 1) return;

    const conversationTitle = currentMessages
      .find(msg => msg.role === 'contact')?.content.substring(0, 50) + '...' || 'Nova conversa';

    const conversation = {
      id: conversationId,
      title: conversationTitle,
      messages: currentMessages,
      phone: userPhone,
      metrics: metrics,
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
    if (currentMessages.length > 1) {
      saveCurrentConversation();
    }
    
    clearMessages();
    setActiveView('chat');
  };

  const handleSelectConversation = (conversation) => {
    if (currentMessages.length > 1) {
      saveCurrentConversation();
    }
    
    // Carregar conversa selecionada
    loadConversation(conversation);
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

  const toggleTheme = () => {
    const newTheme = theme === 'dark' ? 'light' : 'dark';
    setTheme(newTheme);
  };

  const handleLogin = (userData) => {
    login(userData);
  };

  const handleLogout = () => {
    // Salvar conversa atual antes de fazer logout
    if (currentMessages.length > 1) {
      saveCurrentConversation();
    }
    logout();
    clearMessages();
    setActiveView('chat');
  };

  // Mostrar loading enquanto verifica autenticação
  if (authLoading) {
    return (
      <div className="app-loading">
        <div className="loading-spinner"></div>
        <p>Carregando...</p>
      </div>
    );
  }

  // Mostrar tela de login se não estiver autenticado
  if (!isAuthenticated) {
    return (
      <Routes>
        <Route path="*" element={<LoginPage onLogin={handleLogin} />} />
      </Routes>
    );
  }

  const renderCurrentView = () => {
    // Obter última mensagem do agente
    const lastAIMessage = [...currentMessages]
      .reverse()
      .find(msg => msg.role === 'agent');

    switch (activeView) {
      case 'chat':
        return (
          <>
            <ChatContainer 
              messages={currentMessages}
              onSendMessage={handleSendMessage}
              isLoading={isLoading}
              theme={theme}
              onToggleTheme={toggleTheme}
              agentType={settings.agentType || 'SDR'}
            />
            {chatError && (
              <div className="error-banner">
                ⚠️ {chatError}
              </div>
            )}
          </>
        );
      
      case 'metrics':
        return (
          <MetricsPanel 
            metrics={metrics}
            lastMessage={lastAIMessage}
            settings={settings}
          />
        );
      
      case 'history':
        return (
          <ConversationHistory 
            conversations={conversations}
            onSelectConversation={handleSelectConversation}
            onDeleteConversation={handleDeleteConversation}
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
            onPhoneChange={() => {}} // Phone vem do .env agora
          />
        );
      
      case 'profile':
        return (
          <UserProfile 
            userStats={getUserStats()}
          />
        );
      
      default:
        return null;
    }
  };

  return (
    <div className="app">
      <Routes>
        {/* Master Admin Routes (Protected) */}
        <Route path="/admin/master/*" element={<AdminMasterLayout />} />
        
        {/* Main App Routes */}
        <Route path="/*" element={
          <MainLayout
            activeView={activeView}
            onViewChange={setActiveView}
            onNewChat={handleNewChat}
            onLogout={handleLogout}
            conversations={conversations}
            user={user}
          >
            {renderCurrentView()}
          </MainLayout>
        } />
      </Routes>
    </div>
  );
}

export default App;
