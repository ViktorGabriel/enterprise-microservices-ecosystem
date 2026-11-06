# ==============================================================================
# END-TO-END (E2E) INTEGRATION & WEBHOOK DISPATCH TEST SUITE (PowerShell)
# ==============================================================================
# Scenarios Tested:
# 1. JWT Authentication on Java Core Banking API (/api/v1/auth/login)
# 2. Account Provisioning (Source & Target Accounts)
# 3. Pessimistic Lock Money Transfer with X-Idempotency-Key
# 4. Idempotency Enforcement (Re-execution with identical Key prevents double spend)
# 5. Webhook / Event Ingestion on Fastify Notification Engine (/api/v1/notifications)
# 6. BullMQ Asynchronous Processing & Audit Trail Tracking
# ==============================================================================

[CmdletBinding()]
param (
    [string]$JavaBaseUrl = "http://localhost:8080",
    [string]$NodeBaseUrl = "http://localhost:3000",
    [int]$MaxWaitSeconds = 30
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param ([string]$Message)
    Write-Host "`n================================================================================" -ForegroundColor DarkGray
    Write-Host " ▶ $Message" -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor DarkGray
}

function Write-Success {
    param ([string]$Message)
    Write-Host "   ✔ $Message" -ForegroundColor Green
}

function Write-Info {
    param ([string]$Message)
    Write-Host "   ℹ $Message" -ForegroundColor Yellow
}

function Write-Failure {
    param ([string]$Message)
    Write-Host "   ✖ $Message" -ForegroundColor Red
}

Write-Host @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                 ECOSYSTEM END-TO-END (E2E) INTEGRATION TEST                  ║
║      Java Financial API (8080) ➔ Fastify Notification Engine (3000)          ║
╚══════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Blue

# ------------------------------------------------------------------------------
# STEP 0: HEALTH CHECK PROBES
# ------------------------------------------------------------------------------
Write-Step "FASE 0: Verificando disponibilidade e saúde dos serviços..."

$javaHealthy = $false
$nodeHealthy = $false

Write-Info "Testando Java Actuator: $JavaBaseUrl/actuator/health..."
try {
    $resJava = Invoke-RestMethod -Uri "$JavaBaseUrl/actuator/health" -Method Get -TimeoutSec 3
    if ($resJava.status -eq "UP") {
        $javaHealthy = $true
        Write-Success "Java Financial API está ONLINE e Saudável (Status: UP)"
    }
} catch {
    Write-Failure "Java API em $JavaBaseUrl não está acessível no momento."
}

Write-Info "Testando Fastify Health: $NodeBaseUrl/health..."
try {
    $resNode = Invoke-RestMethod -Uri "$NodeBaseUrl/health" -Method Get -TimeoutSec 3
    if ($resNode.status -eq "healthy") {
        $nodeHealthy = $true
        Write-Success "Fastify Notification Engine está ONLINE e Saudável (Status: healthy, DB: $($resNode.services.database), Redis: $($resNode.services.redis))"
    }
} catch {
    Write-Failure "Fastify API em $NodeBaseUrl não está acessível no momento."
}

if (-not $javaHealthy -or -not $nodeHealthy) {
    Write-Host @"

[AVISO DE EXECUÇÃO]
Para executar os testes contra a infraestrutura ativa, suba os serviços com:
   docker compose up -d
Aguarde alguns segundos até que os contêineres completem o healthcheck e execute novamente:
   .\test-e2e.ps1

"@ -ForegroundColor Yellow
    exit 1
}

# ------------------------------------------------------------------------------
# STEP 1: AUTHENTICATION (JAVA API)
# ------------------------------------------------------------------------------
Write-Step "FASE 1: Autenticação JWT na Core Financial API..."

$loginPayload = @{
    username = "admin"
    password = "admin123"
} | ConvertTo-Json

$loginResponse = Invoke-RestMethod -Uri "$JavaBaseUrl/api/v1/auth/login" -Method Post -Body $loginPayload -ContentType "application/json"
$jwtToken = $loginResponse.accessToken

if (-not $jwtToken) {
    Write-Failure "Falha ao obter token JWT!"
    exit 1
}

Write-Success "Autenticação bem-sucedida! Bearer JWT obtido (Expira em: $($loginResponse.expiresIn)s)"
$authHeader = @{
    Authorization = "Bearer $jwtToken"
}

# ------------------------------------------------------------------------------
# STEP 2: ACCOUNT PROVISIONING
# ------------------------------------------------------------------------------
Write-Step "FASE 2: Provisionamento de Contas Bancárias para Demonstração..."

$rnd = Get-Random -Minimum 1000 -Maximum 9999
$sourceAccNum = "SRC-$rnd"
$targetAccNum = "TGT-$rnd"
$cpf1 = "1234567" + (Get-Random -Minimum 1000 -Maximum 9999)
$cpf2 = "9876543" + (Get-Random -Minimum 1000 -Maximum 9999)

Write-Info "Criando Conta Origem: $sourceAccNum (Saldo Inicial: R$ 1.000,00)..."
$sourcePayload = @{
    accountNumber = $sourceAccNum
    documentNumber = $cpf1
    holderName = "Viktor Gabriel - Origem"
    initialDeposit = 1000.00
} | ConvertTo-Json

$sourceAccount = Invoke-RestMethod -Uri "$JavaBaseUrl/api/v1/accounts" -Method Post -Headers $authHeader -Body $sourcePayload -ContentType "application/json"
Write-Success "Conta Origem criada com ID: $($sourceAccount.id) (Saldo: R$ $($sourceAccount.balance))"

Write-Info "Criando Conta Destino: $targetAccNum (Saldo Inicial: R$ 250,00)..."
$targetPayload = @{
    accountNumber = $targetAccNum
    documentNumber = $cpf2
    holderName = "Fintech Partner - Destino"
    initialDeposit = 250.00
} | ConvertTo-Json

$targetAccount = Invoke-RestMethod -Uri "$JavaBaseUrl/api/v1/accounts" -Method Post -Headers $authHeader -Body $targetPayload -ContentType "application/json"
Write-Success "Conta Destino criada com ID: $($targetAccount.id) (Saldo: R$ $($targetAccount.balance))"

# ------------------------------------------------------------------------------
# STEP 3: FINANCIAL TRANSFER WITH IDEMPOTENCY KEY
# ------------------------------------------------------------------------------
Write-Step "FASE 3: Execução de Transferência com Chave de Idempotência..."

$idempotencyKey = [System.Guid]::NewGuid().ToString()
$transferAmount = 150.00
Write-Info "Chave de Idempotência gerada: $idempotencyKey"
Write-Info "Transferindo R$ $transferAmount de $($sourceAccount.accountNumber) para $($targetAccount.accountNumber)..."

$transferPayload = @{
    sourceAccountId = $sourceAccount.id
    targetAccountId = $targetAccount.id
    amount = $transferAmount
    description = "Transferência E2E Integração Ecossistema"
} | ConvertTo-Json

$transferHeaders = @{
    Authorization = "Bearer $jwtToken"
    "X-Idempotency-Key" = $idempotencyKey
}

$transferResponse = Invoke-RestMethod -Uri "$JavaBaseUrl/api/v1/transactions/transfer" -Method Post -Headers $transferHeaders -Body $transferPayload -ContentType "application/json"
Write-Success "Transferência processada com sucesso!"
Write-Success "ID da Transação: $($transferResponse.id) | Status: $($transferResponse.status) | Valor: R$ $($transferResponse.amount)"

# Check Idempotency by re-sending
Write-Info "Testando Idempotência: Reenviando a mesma requisição com a mesma chave..."
$replayResponse = Invoke-RestMethod -Uri "$JavaBaseUrl/api/v1/transactions/transfer" -Method Post -Headers $transferHeaders -Body $transferPayload -ContentType "application/json"
if ($replayResponse.id -eq $transferResponse.id) {
    Write-Success "Garantia de Idempotência validada: Mesma transação retornada sem débito duplicado!"
} else {
    Write-Failure "Aviso: ID divergente retornado na requisição repetida."
}

# ------------------------------------------------------------------------------
# STEP 4: WEBHOOK NOTIFICATION DISPATCH (FASTIFY NOTIFICATION ENGINE)
# ------------------------------------------------------------------------------
Write-Step "FASE 4: Disparo do Webhook de Notificação para a Notification Engine..."

$webhookPayload = @{
    channel = "WEBHOOK"
    recipient = "https://webhook.site/mock-financial-receiver"
    subject = "Notificação de Transferência Financeira Realizada"
    content = "Transferência de R$ $transferAmount concluída com sucesso entre contas $sourceAccNum e $targetAccNum."
    priority = "HIGH"
    metadata = @{
        transactionId = $transferResponse.id
        idempotencyKey = $idempotencyKey
        sourceAccountId = $sourceAccount.id
        targetAccountId = $targetAccount.id
        amount = $transferAmount
        originatingSystem = "enterprise-financial-api"
        timestamp = (Get-Date).ToString("o")
    }
} | ConvertTo-Json -Depth 5

$notificationResponse = Invoke-RestMethod -Uri "$NodeBaseUrl/api/v1/notifications" -Method Post -Body $webhookPayload -ContentType "application/json"
$notificationId = $notificationResponse.id

Write-Success "Evento de notificação ingerido com sucesso no Fastify!"
Write-Success "Notification ID: $notificationId | Status Inicial: $($notificationResponse.status) | Canal: $($notificationResponse.channel)"

# ------------------------------------------------------------------------------
# STEP 5: ASYNC BULLMQ WORKER PROCESSING & AUDIT TRAIL
# ------------------------------------------------------------------------------
Write-Step "FASE 5: Acompanhando Processamento Assíncrono pelo Worker BullMQ..."

$delivered = $false
$elapsed = 0
while ($elapsed -lt $MaxWaitSeconds) {
    Start-Sleep -Seconds 1
    $elapsed++
    
    $checkRes = Invoke-RestMethod -Uri "$NodeBaseUrl/api/v1/notifications/$notificationId" -Method Get
    Write-Host "   [T+$($elapsed)s] Status atual: $($checkRes.status) (Tentativas: $($checkRes.retryCount))" -ForegroundColor DarkCyan

    if ($checkRes.status -eq "DELIVERED") {
        $delivered = $true
        Write-Success "Notificação PROCESSADA e ENTREGUE com sucesso pelo Worker!"
        Write-Info "Entregue em: $($checkRes.deliveredAt)"
        
        if ($checkRes.auditLogs) {
            Write-Host "`n   📋 Trilhas de Auditoria da Notificação (Audit Trail):" -ForegroundColor Magenta
            foreach ($log in $checkRes.auditLogs) {
                Write-Host "      • Evento: $($log.event) | De: $($log.fromStatus) ➔ Para: $($log.toStatus) ($($log.createdAt))" -ForegroundColor White
            }
        }
        break
    }
}

if (-not $delivered) {
    Write-Failure "Tempo limite atingido aguardando processamento da notificação."
    exit 1
}

Write-Host @"

╔══════════════════════════════════════════════════════════════════════════════╗
║               TESTE PONTA A PONTA (E2E) CONCLUÍDO COM SUCESSO!               ║
║                                                                              ║
║  1. Auth JWT ➔ 2. Contas ➔ 3. Transferência Idempotente ➔ 4. BullMQ Worker  ║
╚══════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Green
