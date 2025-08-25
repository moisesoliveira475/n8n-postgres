# n8n-postgres: Setup Completo com PostgreSQL

[![n8n](https://img.shields.io/badge/n8n-FF6B6B?style=for-the-badge&logo=n8n&logoColor=white)](https://n8n.io/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://docker.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-336791?style=for-the-badge&logo=postgresql&logoColor=white)](https://postgresql.org/)

> **Implementações completas do n8n com PostgreSQL - Do uso pessoal à escala empresarial**

## 📋 Sobre o Projeto

Este repositório oferece **duas implementações distintas** do n8n (plataforma de automação de fluxo de trabalho) com PostgreSQL, cada uma otimizada para cenários específicos de uso:

- **🏠 Standard Mode** - Configuração simples para uso pessoal e desenvolvimento
- **🏢 Queue Mode** - Arquitetura escalável para uso empresarial

Ambas as implementações utilizam Docker Compose para orquestração e incluem scripts de automação para facilitar a configuração e manutenção.

## 🎯 Comparação dos Modos

### 📊 Visão Geral Comparativa

| Aspecto | Standard Mode | Queue Mode |
|---------|---------------|------------|
| **Complexidade** | 🟢 Simples | 🟡 Intermediária |
| **Escalabilidade** | 🟡 Limitada | 🟢 Alta |
| **Recursos necessários** | 🟢 Baixos | 🟠 Médios/Altos |
| **Tempo de setup** | 🟢 < 10 min | 🟡 20-30 min |
| **Público-alvo** | 🏠 Pessoal/Dev | 🏢 Empresarial |
| **Manutenção** | 🟢 Mínima | 🟡 Moderada |

## 🏠 Standard Mode

### 🎯 Para Quem é Ideal
- **Desenvolvedores** fazendo testes e prototipagem
- **Uso pessoal** com automações domésticas
- **Pequenas equipes** (1-5 usuários)
- **Projetos de aprendizado** e experimentação
- **Freelancers** com workflows simples

### ✨ Características
- ✅ **Setup ultra-rápido** com script automatizado
- ✅ **Cloudflare Tunnel** integrado para exposição segura
- ✅ **Baixo consumo de recursos** (< 1GB RAM)
- ✅ **Interface única** consolidada
- ✅ **Ideal para desenvolvimento** local

### 🏗️ Arquitetura Standard
```
Internet → Cloudflare Tunnel → n8n (porta 5678) → PostgreSQL
```

### 🚀 Como Usar
```bash
cd standard/
./start.sh n8n.seudominio.com
```

### ✅ Prós
- **Simplicidade máxima** - Um comando e está funcionando
- **Recursos mínimos** - Roda até em Raspberry Pi
- **Exposição segura** via Cloudflare (gratuito)
- **Perfeito para testes** e desenvolvimento
- **Manutenção zero** - Funciona e esquece

### ❌ Contras
- **Não escala** - Limitado a poucos workflows simultâneos
- **Single point of failure** - Se o container cair, tudo para
- **Performance limitada** - Para workloads pesados
- **Sem redundância** - Não há backup automático de execução

---

## 🏢 Queue Mode

### 🎯 Para Quem é Ideal
- **Empresas** com alta demanda de automação
- **Equipes de desenvolvimento** com workflows complexos
- **Ambientes de produção** críticos
- **Organizações** que processam milhares de workflows/dia
- **Cenários de alta disponibilidade**

### ✨ Características
- ✅ **Escalabilidade horizontal** com workers dedicados
- ✅ **Traefik como reverse proxy** com SSL automático
- ✅ **Redis para queue management** 
- ✅ **Separação de responsabilidades** (main, worker, webhook)
- ✅ **Monitoramento avançado** integrado
- ✅ **Alta disponibilidade** e tolerância a falhas

### 🏗️ Arquitetura Queue Mode
```
Internet → Traefik (SSL) → n8n-main → Redis Queue
                        ↓
                   n8n-workers (escaláveis)
                        ↓
                   PostgreSQL
```

### 🚀 Como Usar
```bash
cd queue-mode/
./start.sh
```

### ✅ Prós
- **Escalabilidade infinita** - Adicione workers conforme necessário
- **Alta performance** - Processamento paralelo de workflows
- **Tolerância a falhas** - Workers podem falhar sem afetar o sistema
- **Monitoramento completo** - Dashboard Traefik + métricas Redis
- **Produção-ready** - Certificados SSL automáticos
- **Separação de concerns** - Webhooks dedicados

### ❌ Contras
- **Complexidade maior** - Mais componentes para gerenciar
- **Recursos elevados** - Múltiplos containers (2-4GB RAM)
- **Setup mais demorado** - Configuração de certificados e DNS
- **Curva de aprendizado** - Requer conhecimento de Traefik/Redis
- **Over-engineering** para uso pessoal

---

## 🔄 Componentes por Modo

### Standard Mode (3 containers)
```yaml
services:
  - n8n (interface + processamento)
  - postgres (banco de dados)
  - cloudflared (túnel - opcional)
```

### Queue Mode (6+ containers)
```yaml
services:
  - traefik (reverse proxy + SSL)
  - n8n-main (interface principal)
  - n8n-worker (processamento)
  - n8n-webhook (webhooks dedicados)
  - redis (message queue)
  - postgres (banco de dados)
  - cloudflare-ddns (DNS automático)
```

## 📈 Casos de Uso Recomendados

### 🏠 Use Standard Mode quando:
- ⭐ **Desenvolvimento local** e testes
- ⭐ **Automações pessoais** (casa inteligente, notificações)
- ⭐ **Projetos de aprendizado** do n8n
- ⭐ **Freelancers** com workflows simples
- ⭐ **Prototipagem rápida** de automações
- ⭐ **Recursos limitados** (VPS básico, Raspberry Pi)

### 🏢 Use Queue Mode quando:
- 🚀 **Ambiente de produção** empresarial
- 🚀 **Alto volume** de execuções (>1000/dia)
- 🚀 **Workflows complexos** com processamento pesado
- 🚀 **Equipes grandes** (10+ usuários)
- 🚀 **Necessidade de redundância** e alta disponibilidade
- 🚀 **Integrações críticas** para o negócio
- 🚀 **Compliance** e auditoria avançada

## 🛠️ Instalação Rápida

### Standard Mode
```bash
# Clone o repositório
git clone https://github.com/moisesoliveira475/n8n-postgres.git
cd n8n-postgres/standard

# Execute o setup (substitua pelo seu domínio)
./start.sh n8n.meudominio.com

# Acesse em https://n8n.meudominio.com
```

### Queue Mode
```bash
# Clone o repositório
git clone https://github.com/moisesoliveira475/n8n-postgres.git
cd n8n-postgres/queue-mode

# Configure as variáveis (copie e edite)
cp .env.example .env
nano .env

# Execute o setup
./start.sh

# Acesse Traefik: https://traefik.seudominio.com
# Acesse n8n: https://n8n.seudominio.com
```

## 📚 Documentação Detalhada

- **[Standard Mode - Guia Completo](./standard/README.md)**
  - Setup com Cloudflare Tunnel
  - Configuração de API
  - Troubleshooting

- **[Queue Mode - Guia Empresarial](./queue-mode/README.md)**
  - Arquitetura escalável
  - Configuração Traefik + SSL
  - Monitoramento e manutenção

- **[Cloudflare Tunnel Setup](./standard/cloudflare-guide.md)**
  - Passo a passo para configuração
  - Solução de problemas

## 🤔 Qual Escolher?

### Comece com Standard se:
- ✅ É sua primeira vez com n8n
- ✅ Quer testar rapidamente
- ✅ Uso pessoal ou equipe pequena
- ✅ Recursos limitados

### Migre para Queue quando:
- 📈 Crescimento de usuários (>5)
- 📈 Aumento de workflows (>100 execuções/dia)
- 📈 Necessidade de alta disponibilidade
- 📈 Workflows críticos para o negócio

## 🔄 Migração Entre Modos

É possível migrar do Standard para Queue Mode mantendo os dados:

1. **Backup dos dados** (workflows e credenciais)
2. **Export do banco PostgreSQL**
3. **Configuração do Queue Mode**
4. **Import dos dados**

> 📝 **Nota**: Guia de migração detalhado disponível na documentação de cada modo.

## 🤝 Contribuição

Contribuições são bem-vindas! Para contribuir:

1. Fork o projeto
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para detalhes.

## 🙋‍♂️ Suporte

- **Issues**: Para reportar bugs ou solicitar features
- **Discussions**: Para dúvidas e discussões gerais
- **Wiki**: Documentação adicional e tutoriais

---

**⚡ Comece agora**: Escolha o modo ideal para seu caso de uso e tenha seu n8n funcionando em minutos!
