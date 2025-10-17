import React from 'react';
import { Sun, Moon } from 'lucide-react';
import './Header.css';

const Header = ({ theme, onToggleTheme, agentType, onAgentChange }) => {
  return (
    <header className="chat-header">
      <div className="header-content">
        <div className="header-title">
          <h1>SDR Assistant</h1>
        </div>
        
        <div className="header-actions">
          <button 
            className="theme-toggle" 
            onClick={onToggleTheme}
            aria-label={`Switch to ${theme === 'dark' ? 'light' : 'dark'} theme`}
          >
            {theme === 'dark' ? <Sun size={18} /> : <Moon size={18} />}
          </button>
        </div>
      </div>
    </header>
  );
};

export default Header;