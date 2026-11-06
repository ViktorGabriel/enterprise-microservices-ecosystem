# 🛡️ Relatório de Auditoria de Segurança - CloudSec CLI

- **Versão:** v0.1.0
- **Data/Hora:** 2026-11-06 18:39:14 UTC
- 🔴 **STATUS: FALHA** (Vulnerabilidades Críticas ou Altas Detectadas)

## 📊 Sumário Executivo

| Alvos Inspecionados | Total de Achados | Critical | High | Medium | Low | Duração |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| 7 | 12 | 0 | 11 | 1 | 0 | 0.017s |

## 🔍 Detalhamento de Apontamentos

| Severidade | Regra | Alvo | Descrição | Remediação Recomendada |
| :--- | :--- | :--- | :--- | :--- |
| **HIGH** | `SEC-SEC-007` | `D:\meus-projetos\enterprise-financial-api\src\main\resources\application.yml:5` | A chave 'spring.datasource.url' possui entropia calculada de 5.20, indicando alta aleatoriedade típica de segredos gerados criptograficamente. | Verifique se este valor é um segredo e extraia para variáveis de ambiente. |
| **HIGH** | `SEC-SEC-007` | `D:\meus-projetos\enterprise-financial-api\src\main\resources\application.yml:6` | A chave 'spring.datasource.username' possui entropia calculada de 4.54, indicando alta aleatoriedade típica de segredos gerados criptograficamente. | Verifique se este valor é um segredo e extraia para variáveis de ambiente. |
| **HIGH** | `SEC-SEC-006` | `D:\meus-projetos\enterprise-financial-api\src\main\resources\application.yml:7` | A chave sensível 'spring.datasource.password' contém um valor em texto claro persistido. | Remova credenciais estáticas do arquivo. Utilize injeção via variáveis de ambiente ou serviços de secrets management (HashiCorp Vault, AWS Secrets Manager). |
| **HIGH** | `SEC-SEC-006` | `D:\meus-projetos\enterprise-financial-api\src\main\resources\application.yml:7` | A chave sensível 'security.user.password' contém um valor em texto claro persistido. | Remova credenciais estáticas do arquivo. Utilize injeção via variáveis de ambiente ou serviços de secrets management (HashiCorp Vault, AWS Secrets Manager). |
| **HIGH** | `SEC-SEC-006` | `D:\meus-projetos\enterprise-financial-api\.env.example:4` | A chave sensível 'SPRING_DATASOURCE_PASSWORD' contém um valor em texto claro persistido. | Remova credenciais estáticas do arquivo. Utilize injeção via variáveis de ambiente ou serviços de secrets management (HashiCorp Vault, AWS Secrets Manager). |
| **HIGH** | `SEC-SEC-004` | `D:\meus-projetos\notification-event-engine\.env.example:7` | Padrão de segredo identificado na chave 'DATABASE_URL'. | Não armazene senhas na string de conexão em arquivos de configuração; injete via variáveis em runtime. |
| **HIGH** | `SEC-SEC-006` | `D:\meus-projetos\docker-compose.yml:13` | A chave sensível 'services.postgres.environment.POSTGRES_PASSWORD' contém um valor em texto claro persistido. | Remova credenciais estáticas do arquivo. Utilize injeção via variáveis de ambiente ou serviços de secrets management (HashiCorp Vault, AWS Secrets Manager). |
| **HIGH** | `SEC-SEC-006` | `D:\meus-projetos\docker-compose.yml:60` | A chave sensível 'services.financial-api.environment.SPRING_DATASOURCE_PASSWORD' contém um valor em texto claro persistido. | Remova credenciais estáticas do arquivo. Utilize injeção via variáveis de ambiente ou serviços de secrets management (HashiCorp Vault, AWS Secrets Manager). |
| **HIGH** | `SEC-SEC-006` | `D:\meus-projetos\docker-compose.yml:62` | A chave sensível 'services.financial-api.environment.APP_SECURITY_PASSWORD' contém um valor em texto claro persistido. | Remova credenciais estáticas do arquivo. Utilize injeção via variáveis de ambiente ou serviços de secrets management (HashiCorp Vault, AWS Secrets Manager). |
| **HIGH** | `SEC-SEC-007` | `D:\meus-projetos\docker-compose.yml:91` | A chave 'services.notification-api.environment.DATABASE_URL' possui entropia calculada de 5.09, indicando alta aleatoriedade típica de segredos gerados criptograficamente. | Verifique se este valor é um segredo e extraia para variáveis de ambiente. |
| **HIGH** | `SEC-SEC-007` | `D:\meus-projetos\docker-compose.yml:91` | A chave 'services.notification-worker.environment.DATABASE_URL' possui entropia calculada de 5.09, indicando alta aleatoriedade típica de segredos gerados criptograficamente. | Verifique se este valor é um segredo e extraia para variáveis de ambiente. |
| **MEDIUM** | `SEC-SEC-006` | `D:\meus-projetos\enterprise-financial-api\.env.example:8` | A chave 'APP_SECURITY_PASSWORD' contém um valor padrão/mock ('admin123') que pode ser esquecido e enviado para produção. | Remova credenciais estáticas do arquivo. Utilize injeção via variáveis de ambiente ou serviços de secrets management (HashiCorp Vault, AWS Secrets Manager). |
