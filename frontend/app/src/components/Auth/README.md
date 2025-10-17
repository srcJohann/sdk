# Sistema de Autenticação

## 📋 Descrição

Sistema de login completo e funcional para a aplicação DOM 360 SDR Debug, com design consistente e recursos de persistência de sessão.

## 🎨 Características Visuais

- ✅ **Design Consistente**: Segue o mesmo padrão visual do resto da aplicação
- ✅ **Logo Centralizada**: Logo DOM 360 acima dos campos de login
- ✅ **Ícones Monocromáticos**: Usando Lucide React (User, Lock, Eye, EyeOff)
- ✅ **Animações Suaves**: Transições e feedback visual
- ✅ **Responsivo**: Adapta-se perfeitamente a mobile e desktop
- ✅ **Temas**: Suporta tema claro e escuro

## 🔧 Funcionalidades

### Campos do Formulário
- **Usuário**: Campo de texto com validação
- **Senha**: Campo de senha com botão de mostrar/ocultar
- **Manter Logado**: Checkbox para persistência de sessão

### Validações
- Campo usuário não pode estar vazio
- Senha deve ter no mínimo 4 caracteres
- Mensagens de erro contextuais e claras

### Persistência de Sessão
- **Com "Manter Logado"**: Usa `localStorage` (permanece após fechar o navegador)
- **Sem "Manter Logado"**: Usa `sessionStorage` (expira ao fechar o navegador)

## 📁 Arquivos

```
src/components/Auth/
├── LoginPage.jsx       # Componente principal de login
├── LoginPage.css       # Estilos da página de login
└── README.md          # Documentação

src/hooks/
└── useAuth.js         # Hook de autenticação
```

## 🚀 Como Usar

### 1. Importar no App.jsx

```jsx
import LoginPage from './components/Auth/LoginPage';
import useAuth from './hooks/useAuth';

function App() {
  const { isAuthenticated, user, isLoading, login, logout } = useAuth();
  
  // Mostrar loading
  if (isLoading) {
    return <LoadingScreen />;
  }
  
  // Mostrar login se não autenticado
  if (!isAuthenticated) {
    return <LoginPage onLogin={login} />;
  }
  
  // Aplicação autenticada
  return <MainApp user={user} onLogout={logout} />;
}
```

### 2. Credenciais de Teste

Por padrão, o sistema aceita qualquer combinação de usuário/senha para demonstração.

Para implementar autenticação real, modifique a função `handleSubmit` em `LoginPage.jsx`:

```jsx
const handleSubmit = async (e) => {
  e.preventDefault();
  
  if (!validateForm()) return;
  
  setIsLoading(true);
  
  try {
    // Substituir por chamada real à API
    const response = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        username: formData.username,
        password: formData.password
      })
    });
    
    const data = await response.json();
    
    if (response.ok) {
      // Salvar token
      if (formData.rememberMe) {
        localStorage.setItem('auth_token', data.token);
        localStorage.setItem('auth_username', data.username);
      } else {
        sessionStorage.setItem('auth_token', data.token);
        sessionStorage.setItem('auth_username', data.username);
      }
      
      onLogin(data);
    } else {
      setErrors({ general: data.message });
    }
  } catch (error) {
    setErrors({ general: 'Erro ao conectar ao servidor' });
  } finally {
    setIsLoading(false);
  }
};
```

## 🎯 Hook useAuth

O hook `useAuth` gerencia o estado de autenticação da aplicação:

### Propriedades Retornadas

```typescript
{
  isAuthenticated: boolean;  // Usuário está autenticado?
  user: {                    // Dados do usuário (ou null)
    username: string;
    token: string;
    rememberMe: boolean;
  } | null;
  isLoading: boolean;        // Verificando autenticação?
  login: (userData) => void; // Fazer login
  logout: () => void;        // Fazer logout
  checkAuth: () => void;     // Re-verificar autenticação
}
```

### Exemplo de Uso

```jsx
const { isAuthenticated, user, logout } = useAuth();

return (
  <div>
    {isAuthenticated ? (
      <>
        <p>Bem-vindo, {user.username}!</p>
        <button onClick={logout}>Sair</button>
      </>
    ) : (
      <p>Você precisa fazer login</p>
    )}
  </div>
);
```

## 🔒 Segurança

### Boas Práticas Implementadas

- ✅ Validação de campos no frontend
- ✅ Feedback visual de erros
- ✅ Desabilitar botões durante carregamento
- ✅ Autocomplete apropriado nos campos
- ✅ ARIA labels para acessibilidade
- ✅ Limpar tokens ao fazer logout

### Recomendações para Produção

1. **HTTPS**: Use sempre HTTPS em produção
2. **Token JWT**: Implemente tokens JWT com expiração
3. **Refresh Tokens**: Para sessões longas
4. **Rate Limiting**: Limite tentativas de login
5. **2FA**: Considere autenticação de dois fatores
6. **CSRF Protection**: Proteção contra CSRF
7. **Hash de Senhas**: Use bcrypt/argon2 no backend

## 🎨 Personalização

### Alterar Logo

Substitua o arquivo em: `src/assets/logo_dom360.png`

### Cores e Estilos

As cores são definidas nas variáveis CSS em `index.css`:

```css
:root {
  --accent-color: #10a37f;
  --error-color: #ef4444;
  --border-color: #3a3a3a;
  /* ... */
}
```

### Textos

Modifique diretamente em `LoginPage.jsx`:

```jsx
<h1 className="login-title">Bem-vindo de volta</h1>
<p className="login-subtitle">Acesse sua conta para continuar</p>
```

## 📱 Responsividade

O layout adapta-se automaticamente:

- **Desktop**: Card centralizado de 420px
- **Tablet**: Card adaptado com padding reduzido
- **Mobile**: Layout otimizado para telas pequenas

## 🐛 Troubleshooting

### Login não persiste após refresh

Verifique se o hook `useAuth` está sendo chamado no componente raiz (`App.jsx`).

### Usuário sempre deslogado

Verifique se `checkAuth()` está sendo executado no `useEffect`:

```jsx
useEffect(() => {
  checkAuth();
}, []);
```

### Erro de CORS

Configure o backend para aceitar requisições do frontend:

```javascript
// Express.js exemplo
app.use(cors({
  origin: 'http://localhost:5173',
  credentials: true
}));
```

## 📝 Changelog

### v1.0.0 (2025-10-14)
- ✅ Implementação inicial do sistema de login
- ✅ Design consistente com a aplicação
- ✅ Validações de formulário
- ✅ Persistência de sessão (localStorage/sessionStorage)
- ✅ Botão de logout na sidebar
- ✅ Loading state
- ✅ Tela de loading durante verificação de auth
- ✅ Responsividade completa
- ✅ Suporte a temas claro/escuro

## 🤝 Contribuindo

Para contribuir com melhorias:

1. Mantenha a consistência visual
2. Adicione testes se possível
3. Documente mudanças importantes
4. Siga os padrões de código existentes

---

**Desenvolvido com ❤️ para DOM 360**
