import React from 'react';
import Sidebar from './Sidebar';
import './MainLayout.css';

const MainLayout = ({ 
  activeView, 
  onViewChange, 
  onNewChat, 
  onLogout,
  conversations,
  user,
  children 
}) => {
  return (
    <div className="main-layout">
      <Sidebar 
        activeView={activeView}
        onViewChange={onViewChange}
        onNewChat={onNewChat}
        onLogout={onLogout}
        conversations={conversations}
        user={user}
      />
      <main className="main-content">
        {children}
      </main>
    </div>
  );
};

export default MainLayout;