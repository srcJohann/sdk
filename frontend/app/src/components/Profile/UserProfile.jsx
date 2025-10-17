import React, { useState } from 'react';
import { User, Edit3, Camera, Mail, Calendar, MessageSquare, Clock, Award } from 'lucide-react';
import './UserProfile.css';

const UserProfile = ({ userStats }) => {
  const [isEditing, setIsEditing] = useState(false);
  const [userInfo, setUserInfo] = useState({
    name: 'Usuário',
    email: 'usuario@exemplo.com',
    joinDate: '2024-01-15',
    avatar: null,
    bio: 'Explorando as possibilidades da inteligência artificial.',
  });

  const handleSave = () => {
    setIsEditing(false);
    // Aqui você salvaria as informações do usuário
  };

  const handleAvatarChange = (event) => {
    const file = event.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (e) => {
        setUserInfo({ ...userInfo, avatar: e.target.result });
      };
      reader.readAsDataURL(file);
    }
  };

  const stats = userStats || {
    totalConversations: 42,
    totalMessages: 158,
    timeSpent: '12h 34m',
    favoriteModel: 'GPT-4',
    averageSessionTime: '18min',
    streak: 7,
  };

  return (
    <div className="page-container">
      <div className="page-header">
        <h1 className="page-title">
          <User size={24} />
          Meu Perfil
        </h1>
      </div>

      <div className="page-content page-content-centered">
        {/* Card do Usuário */}
        <div className="content-section user-card">
          <div className="avatar-section">
            <div className="avatar-container">
              {userInfo.avatar ? (
                <img src={userInfo.avatar} alt="Avatar" className="user-avatar" />
              ) : (
                <div className="default-avatar">
                  <User size={40} />
                </div>
              )}
              {isEditing && (
                <label className="avatar-upload">
                  <Camera size={16} />
                  <input
                    type="file"
                    accept="image/*"
                    onChange={handleAvatarChange}
                    style={{ display: 'none' }}
                  />
                </label>
              )}
            </div>
          </div>

          <div className="user-info">
            {isEditing ? (
              <div className="edit-form">
                <input
                  type="text"
                  value={userInfo.name}
                  onChange={(e) => setUserInfo({ ...userInfo, name: e.target.value })}
                  className="edit-input"
                  placeholder="Seu nome"
                />
                <input
                  type="email"
                  value={userInfo.email}
                  onChange={(e) => setUserInfo({ ...userInfo, email: e.target.value })}
                  className="edit-input"
                  placeholder="Seu email"
                />
                <textarea
                  value={userInfo.bio}
                  onChange={(e) => setUserInfo({ ...userInfo, bio: e.target.value })}
                  className="edit-textarea"
                  placeholder="Conte um pouco sobre você..."
                  rows="3"
                />
                <div className="edit-actions">
                  <button className="save-btn" onClick={handleSave}>
                    Salvar
                  </button>
                  <button className="cancel-btn" onClick={() => setIsEditing(false)}>
                    Cancelar
                  </button>
                </div>
              </div>
            ) : (
              <div className="user-details">
                <div className="user-name-section">
                  <h2 className="user-name">{userInfo.name}</h2>
                  <button
                    className="edit-btn"
                    onClick={() => setIsEditing(true)}
                    title="Editar perfil"
                  >
                    <Edit3 size={16} />
                  </button>
                </div>
                
                <div className="user-meta">
                  <div className="meta-item">
                    <Mail size={14} />
                    <span>{userInfo.email}</span>
                  </div>
                  <div className="meta-item">
                    <Calendar size={14} />
                    <span>Membro desde {new Date(userInfo.joinDate).toLocaleDateString('pt-BR')}</span>
                  </div>
                </div>
                
                <p className="user-bio">{userInfo.bio}</p>
              </div>
            )}
          </div>
        </div>

        {/* Estatísticas */}
        <div className="content-section">
          <div className="section-header">
            <h3 className="section-title">Estatísticas de Uso</h3>
          </div>
          
          <div className="cards-grid">
            <div className="info-card stat-card">
              <div className="stat-icon">
                <MessageSquare size={24} />
              </div>
              <div className="stat-info">
                <span className="stat-number">{stats.totalConversations}</span>
                <span className="stat-label">Conversas</span>
              </div>
            </div>

            <div className="info-card stat-card">
              <div className="stat-icon">
                <MessageSquare size={24} />
              </div>
              <div className="stat-info">
                <span className="stat-number">{stats.totalMessages}</span>
                <span className="stat-label">Mensagens</span>
              </div>
            </div>

            <div className="info-card stat-card">
              <div className="stat-icon">
                <Clock size={24} />
              </div>
              <div className="stat-info">
                <span className="stat-number">{stats.timeSpent}</span>
                <span className="stat-label">Tempo total</span>
              </div>
            </div>

            <div className="info-card stat-card">
              <div className="stat-icon">
                <Award size={24} />
              </div>
              <div className="stat-info">
                <span className="stat-number">{stats.streak}</span>
                <span className="stat-label">Dias consecutivos</span>
              </div>
            </div>
          </div>
        </div>

        {/* Preferências */}
        <div className="content-section">
          <div className="section-header">
            <h3 className="section-title">Preferências</h3>
          </div>
          
          <div className="preference-items">
            <div className="label-value-pair">
              <span className="label-text">Modelo Favorito</span>
              <span className="value-text">{stats.favoriteModel}</span>
            </div>
            
            <div className="label-value-pair">
              <span className="label-text">Tempo Médio de Sessão</span>
              <span className="value-text">{stats.averageSessionTime}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default UserProfile;