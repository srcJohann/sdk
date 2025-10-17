# DOM360 SDK

Sistema completo de chat com agentes de IA, incluindo backend FastAPI, frontend React, autenticação RBAC, multi-tenant e deployment automatizado.

## 🚀 Início Rápido

### Pré-requisitos
- Python 3.8+
- Node.js 16+
- PostgreSQL 12+
- Nginx (opcional, para reverse proxy)

### Instalação e Execução

1. **Clone o repositório:**
   ```bash
   git clone https://github.com/srcJohann/sdk.git
   cd sdk
   ```

2. **Configure o ambiente:**
   ```bash
   # Instale dependências Python
   pip install -r requirements.txt

   # Instale dependências Node.js
   cd frontend/app && npm install && cd ../..
   ```

3. **Configure o banco de dados:**
   - Certifique-se de que PostgreSQL está rodando
   - Edite `.env` com suas credenciais do banco
   - Execute `./start.sh` (ele criará o banco e aplicará o schema automaticamente)

4. **Inicie os serviços:**
   ```bash
   ./start.sh
   ```

   Isso iniciará:
   - Backend FastAPI em http://localhost:3001
   - Frontend React em http://localhost:5173

## 🔧 Configuração com Nginx (Reverse Proxy)

Para usar domínios personalizados:

1. **Instale e configure Nginx:**
   ```bash
   sudo ./setup_nginx.sh
   ```

2. **Adicione ao /etc/hosts:**
   ```
   127.0.0.1 srcjohann.com.br api.srcjohann.com.br
   ```

3. **URLs:**
   - Frontend: http://srcjohann.com.br
   - Backend API: http://api.srcjohann.com.br

## 📁 Estrutura do Projeto

```
├── backend/              # API FastAPI
│   ├── api/             # Rotas da API
│   ├── auth/            # Autenticação e RBAC
│   └── server.py        # Servidor principal
├── frontend/            # Aplicação React
│   └── app/            # App Vite
├── database/           # Schema e migrações
├── docs/               # Documentação completa
├── nginx.conf          # Configuração Nginx
├── start.sh            # Script de inicialização
└── export_schema.py    # Exportar schema do banco
```

## 🔑 Funcionalidades

- **Multi-tenant**: Suporte a múltiplos tenants
- **RBAC**: Controle de acesso baseado em roles
- **Chat com IA**: Integração com agentes de IA
- **Dashboard Admin**: Gestão completa do sistema
- **API REST**: Documentada com Swagger
- **Deployment Automatizado**: Scripts para setup completo

## 📚 Documentação

- [Documentação da API](API_DOCUMENTATION.md)
- [Guia de Instalação Rápida](docs/QUICK_START.md)
- [Arquitetura do Sistema](docs/ARCHITECTURE.md)
- [Guia do Master Admin](docs/MASTER_ADMIN_GUIDE.md)

## 🛠️ Desenvolvimento

### Exportar Schema do Banco
```bash
python export_schema.py
```

### Executar Testes
```bash
# Backend
cd backend && python -m pytest

# Frontend
cd frontend/app && npm test
```

## 🤝 Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo `LICENSE` para detalhes.

## 📞 Suporte

Para suporte, entre em contato através das issues do GitHub ou documentação em `docs/`.

---

**DOM360** - Plataforma de comunicação inteligente com IA.</content>
<parameter name="filePath">/home/johann/ContaboDocs/sdk-deploy/README.md