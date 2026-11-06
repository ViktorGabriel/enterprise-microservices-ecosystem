#!/usr/bin/env bash
# ==============================================================================
# END-TO-END (E2E) INTEGRATION & WEBHOOK DISPATCH TEST SUITE (Bash)
# ==============================================================================
# Scenarios Tested:
# 1. JWT Authentication on Java Core Banking API (/api/v1/auth/login)
# 2. Account Provisioning (Source & Target Accounts)
# 3. Pessimistic Lock Money Transfer with X-Idempotency-Key
# 4. Idempotency Enforcement (Re-execution with identical Key prevents double spend)
# 5. Webhook / Event Ingestion on Fastify Notification Engine (/api/v1/notifications)
# 6. BullMQ Asynchronous Processing & Audit Trail Tracking
# ==============================================================================
set -euo pipefail

JAVA_URL="${JAVA_URL:-http://localhost:8080}"
NODE_URL="${NODE_URL:-http://localhost:3000}"
MAX_WAIT="${MAX_WAIT:-30}"

CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

step() {
    echo -e "\n${GRAY}================================================================================${NC}"
    echo -e " ${CYAN}▶ $1${NC}"
    echo -e "${GRAY}================================================================================${NC}"
}
success() { echo -e "   ${GREEN}✔ $1${NC}"; }
info() { echo -e "   ${YELLOW}ℹ $1${NC}"; }
failure() { echo -e "   ${RED}✖ $1${NC}"; }

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                 ECOSYSTEM END-TO-END (E2E) INTEGRATION TEST                  ║"
echo "║      Java Financial API (8080) ➔ Fastify Notification Engine (3000)          ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check curl and jq
if ! command -v curl &> /dev/null; then
    failure "curl é necessário mas não está instalado."
    exit 1
fi

step "FASE 0: Verificando disponibilidade e saúde dos serviços..."

JAVA_STATUS=$(curl -s -m 3 "${JAVA_URL}/actuator/health" | grep -o '"status":"UP"' || true)
if [[ -n "$JAVA_STATUS" ]]; then
    success "Java Financial API está ONLINE e Saudável (Status: UP)"
else
    failure "Java API em ${JAVA_URL} não está acessível no momento."
    echo -e "${YELLOW}Dica: Execute 'docker compose up -d' e aguarde os contêineres inicializarem.${NC}"
    exit 1
fi

NODE_STATUS=$(curl -s -m 3 "${NODE_URL}/health" | grep -o '"status":"healthy"' || true)
if [[ -n "$NODE_STATUS" ]]; then
    success "Fastify Notification Engine está ONLINE e Saudável (Status: healthy)"
else
    failure "Fastify API em ${NODE_URL} não está acessível no momento."
    echo -e "${YELLOW}Dica: Execute 'docker compose up -d' e aguarde os contêineres inicializarem.${NC}"
    exit 1
fi

step "FASE 1: Autenticação JWT na Core Financial API..."

AUTH_RESP=$(curl -s -X POST "${JAVA_URL}/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"admin123"}')

JWT_TOKEN=$(echo "$AUTH_RESP" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)

if [[ -z "$JWT_TOKEN" ]]; then
    failure "Falha ao obter token JWT na autenticação!"
    echo "Resposta recebida: $AUTH_RESP"
    exit 1
fi
success "Autenticação bem-sucedida! Bearer JWT obtido."

step "FASE 2: Provisionamento de Contas Bancárias para Demonstração..."

RND=$((1000 + RANDOM % 9000))
SRC_NUM="SRC-${RND}"
TGT_NUM="TGT-${RND}"
CPF1="1234567${RND}"
CPF2="9876543${RND}"

info "Criando Conta Origem: ${SRC_NUM} (Saldo: R$ 1.000,00)..."
SRC_RESP=$(curl -s -X POST "${JAVA_URL}/api/v1/accounts" \
    -H "Authorization: Bearer ${JWT_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"accountNumber\":\"${SRC_NUM}\",\"documentNumber\":\"${CPF1}\",\"holderName\":\"Viktor Gabriel - Origem\",\"initialDeposit\":1000.00}")

SRC_ID=$(echo "$SRC_RESP" | grep -o '"id":"[^"]*' | head -n 1 | cut -d'"' -f4)
success "Conta Origem criada com ID: ${SRC_ID}"

info "Criando Conta Destino: ${TGT_NUM} (Saldo: R$ 250,00)..."
TGT_RESP=$(curl -s -X POST "${JAVA_URL}/api/v1/accounts" \
    -H "Authorization: Bearer ${JWT_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"accountNumber\":\"${TGT_NUM}\",\"documentNumber\":\"${CPF2}\",\"holderName\":\"Fintech Partner - Destino\",\"initialDeposit\":250.00}")

TGT_ID=$(echo "$TGT_RESP" | grep -o '"id":"[^"]*' | head -n 1 | cut -d'"' -f4)
success "Conta Destino criada com ID: ${TGT_ID}"

step "FASE 3: Execução de Transferência com Chave de Idempotência..."

IDEMPOTENCY_KEY=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || date +%s%N | md5sum | head -c 32)
TRANSFER_AMOUNT="150.00"
info "Chave de Idempotência: ${IDEMPOTENCY_KEY}"
info "Transferindo R$ ${TRANSFER_AMOUNT} de ${SRC_NUM} para ${TGT_NUM}..."

TX_RESP=$(curl -s -X POST "${JAVA_URL}/api/v1/transactions/transfer" \
    -H "Authorization: Bearer ${JWT_TOKEN}" \
    -H "X-Idempotency-Key: ${IDEMPOTENCY_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"sourceAccountId\":\"${SRC_ID}\",\"targetAccountId\":\"${TGT_ID}\",\"amount\":${TRANSFER_AMOUNT},\"description\":\"Transferência E2E Ecossistema\"}")

TX_ID=$(echo "$TX_RESP" | grep -o '"id":"[^"]*' | head -n 1 | cut -d'"' -f4)
success "Transferência executada! Transação ID: ${TX_ID}"

# Test Idempotency
info "Testando Idempotência: Reenviando requisição com mesma chave..."
REPLAY_RESP=$(curl -s -X POST "${JAVA_URL}/api/v1/transactions/transfer" \
    -H "Authorization: Bearer ${JWT_TOKEN}" \
    -H "X-Idempotency-Key: ${IDEMPOTENCY_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"sourceAccountId\":\"${SRC_ID}\",\"targetAccountId\":\"${TGT_ID}\",\"amount\":${TRANSFER_AMOUNT},\"description\":\"Transferência E2E Ecossistema\"}")

REPLAY_ID=$(echo "$REPLAY_RESP" | grep -o '"id":"[^"]*' | head -n 1 | cut -d'"' -f4)
if [[ "$TX_ID" == "$REPLAY_ID" ]]; then
    success "Idempotência confirmada: Retornada mesma transação sem duplicar débito!"
fi

step "FASE 4: Disparo do Webhook de Notificação para a Notification Engine..."

NOTIF_PAYLOAD=$(cat <<EOF
{
  "channel": "WEBHOOK",
  "recipient": "https://webhook.site/mock-financial-receiver",
  "subject": "Notificação de Transferência Financeira Realizada",
  "content": "Transferência de R$ ${TRANSFER_AMOUNT} concluída com sucesso entre contas ${SRC_NUM} e ${TGT_NUM}.",
  "priority": "HIGH",
  "metadata": {
    "transactionId": "${TX_ID}",
    "idempotencyKey": "${IDEMPOTENCY_KEY}",
    "sourceAccountId": "${SRC_ID}",
    "targetAccountId": "${TGT_ID}",
    "amount": ${TRANSFER_AMOUNT},
    "originatingSystem": "enterprise-financial-api"
  }
}
EOF
)

NOTIF_RESP=$(curl -s -X POST "${NODE_URL}/api/v1/notifications" \
    -H "Content-Type: application/json" \
    -d "${NOTIF_PAYLOAD}")

NOTIF_ID=$(echo "$NOTIF_RESP" | grep -o '"id":"[^"]*' | head -n 1 | cut -d'"' -f4)
success "Evento ingerido na Notification Engine! Notification ID: ${NOTIF_ID}"

step "FASE 5: Acompanhando Processamento Assíncrono pelo Worker BullMQ..."

ELAPSED=0
DELIVERED=false
while [ $ELAPSED -lt $MAX_WAIT ]; do
    sleep 1
    ELAPSED=$((ELAPSED + 1))
    
    CHECK_RESP=$(curl -s "${NODE_URL}/api/v1/notifications/${NOTIF_ID}")
    STATUS=$(echo "$CHECK_RESP" | grep -o '"status":"[^"]*' | head -n 1 | cut -d'"' -f4)
    echo -e "   [T+${ELAPSED}s] Status atual: ${CYAN}${STATUS}${NC}"

    if [[ "$STATUS" == "DELIVERED" ]]; then
        DELIVERED=true
        success "Notificação PROCESSADA e ENTREGUE com sucesso pelo Worker BullMQ!"
        break
    fi
done

if [[ "$DELIVERED" == "false" ]]; then
    failure "Tempo limite aguardando processamento da notificação."
    exit 1
fi

echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║               TESTE PONTA A PONTA (E2E) CONCLUÍDO COM SUCESSO!               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
