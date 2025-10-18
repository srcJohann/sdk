import React, { useState } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { Lock, User, Eye, EyeOff } from 'lucide-react';
import logoDom360 from '../../assets/logo_dom360.png';
import './LoginPage.css';

const LoginPage = ({ onLogin }) => {
  const [formData, setFormData] = useState({
    username: '',
    password: '',
    rememberMe: false
  });
  const auth = useAuth();
  const [showPassword, setShowPassword] = useState(false);
  const [errors, setErrors] = useState({});
  const [isLoading, setIsLoading] = useState(false);

  const validateForm = () => {
    const newErrors = {};

    if (!formData.username.trim()) {
      newErrors.username = 'O campo usuário é obrigatório';
    }

    if (!formData.password) {
      newErrors.password = 'O campo senha é obrigatório';
    } else if (formData.password.length < 8) {
      // Backend requires min_length=8 for passwords
      newErrors.password = 'A senha deve ter no mínimo 8 caracteres';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!validateForm()) {
      return;
    }

    setIsLoading(true);
    setErrors({});
    try {
      // Attempt real login via AuthContext
      const result = await auth.login(formData.username, formData.password, formData.rememberMe);

      // If parent component needs the callback
      if (onLogin) {
        onLogin(result.user || { username: formData.username });
      }
    } catch (error) {
      setErrors({ general: error.message || 'Erro ao fazer login. Verifique suas credenciais.' });
    } finally {
      setIsLoading(false);
    }
  };

  const handleInputChange = (e) => {
    const { name, value, type, checked } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: type === 'checkbox' ? checked : value
    }));
    
    // Limpar erro do campo quando o usuário começar a digitar
    if (errors[name]) {
      setErrors(prev => ({ ...prev, [name]: '' }));
    }
  };

  return (
    <div className="login-page">
      <div className="login-container">
        {/* Logo */}
        <div className="login-logo">
          <img src={logoDom360} alt="DOM 360" className="logo-image" />
        </div>

        {/* Formulário */}
        <form className="login-form" onSubmit={handleSubmit}>
          {/* Erro geral */}
          {errors.general && (
            <div className="error-message general-error">
              {errors.general}
            </div>
          )}

          {/* Campo de Usuário */}
          <div className="form-group">
            <label htmlFor="username" className="form-label">
              Usuário
            </label>
            <div className="input-wrapper">
              <User className="input-icon" size={18} />
              <input
                type="text"
                id="username"
                name="username"
                className={`form-input ${errors.username ? 'input-error' : ''}`}
                placeholder="Digite seu usuário"
                value={formData.username}
                onChange={handleInputChange}
                disabled={isLoading}
                autoComplete="username"
                autoFocus
              />
            </div>
            {errors.username && (
              <span className="error-message">{errors.username}</span>
            )}
          </div>

          {/* Campo de Senha */}
          <div className="form-group">
            <label htmlFor="password" className="form-label">
              Senha
            </label>
            <div className="input-wrapper">
              <Lock className="input-icon" size={18} />
              <input
                type={showPassword ? 'text' : 'password'}
                id="password"
                name="password"
                className={`form-input ${errors.password ? 'input-error' : ''}`}
                placeholder="Digite sua senha"
                value={formData.password}
                onChange={handleInputChange}
                disabled={isLoading}
                autoComplete="current-password"
              />
              <button
                type="button"
                className="password-toggle"
                onClick={() => setShowPassword(!showPassword)}
                disabled={isLoading}
                aria-label={showPassword ? 'Ocultar senha' : 'Mostrar senha'}
              >
                {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
            {errors.password && (
              <span className="error-message">{errors.password}</span>
            )}
          </div>

          {/* Checkbox Manter Logado */}
          <div className="form-group checkbox-group">
            <label className="checkbox-label">
              <input
                type="checkbox"
                name="rememberMe"
                checked={formData.rememberMe}
                onChange={handleInputChange}
                disabled={isLoading}
                className="checkbox-input"
              />
              <span className="checkbox-custom"></span>
              <span className="checkbox-text">Manter logado</span>
            </label>
          </div>

          {/* Botão de Submit */}
          <button
            type="submit"
            className="login-button"
            disabled={isLoading}
          >
            {isLoading ? (
              <>
                <span className="spinner"></span>
                Entrando...
              </>
            ) : (
              'Entrar'
            )}
          </button>
        </form>
      </div>
    </div>
  );
};

export default LoginPage;
