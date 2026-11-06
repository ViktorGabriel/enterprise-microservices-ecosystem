-- ==============================================================================
-- ECOSYSTEM DATABASE INITIALIZATION SCRIPT
-- ==============================================================================
-- Creates the isolated notification_engine database alongside the default financial_db.
-- Schema for notification_engine (PostgreSQL) corresponding to Prisma Data Model.
-- ==============================================================================

CREATE DATABASE notification_engine;

\c notification_engine;

-- Custom Enums
CREATE TYPE "Channel" AS ENUM ('EMAIL', 'SMS', 'PUSH', 'WEBHOOK');
CREATE TYPE "NotificationStatus" AS ENUM ('PENDING', 'QUEUED', 'PROCESSING', 'DELIVERED', 'FAILED', 'CANCELLED');
CREATE TYPE "NotificationPriority" AS ENUM ('LOW', 'NORMAL', 'HIGH', 'CRITICAL');
CREATE TYPE "BatchStatus" AS ENUM ('PENDING', 'PROCESSING', 'COMPLETED', 'PARTIALLY_FAILED', 'FAILED');

-- Batch Dispatches Table
CREATE TABLE IF NOT EXISTS "batch_dispatches" (
    "id" TEXT NOT NULL,
    "totalItems" INTEGER NOT NULL DEFAULT 0,
    "processedItems" INTEGER NOT NULL DEFAULT 0,
    "successfulItems" INTEGER NOT NULL DEFAULT 0,
    "failedItems" INTEGER NOT NULL DEFAULT 0,
    "status" "BatchStatus" NOT NULL DEFAULT 'PENDING',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "batch_dispatches_pkey" PRIMARY KEY ("id")
);

-- Notifications Table
CREATE TABLE IF NOT EXISTS "notifications" (
    "id" TEXT NOT NULL,
    "batch_id" TEXT,
    "channel" "Channel" NOT NULL,
    "recipient" TEXT NOT NULL,
    "subject" TEXT,
    "content" TEXT NOT NULL,
    "metadata" JSONB,
    "priority" "NotificationPriority" NOT NULL DEFAULT 'NORMAL',
    "status" "NotificationStatus" NOT NULL DEFAULT 'PENDING',
    "retry_count" INTEGER NOT NULL DEFAULT 0,
    "max_retries" INTEGER NOT NULL DEFAULT 3,
    "last_error" TEXT,
    "scheduled_at" TIMESTAMP(3),
    "delivered_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- Audit Logs Table
CREATE TABLE IF NOT EXISTS "notification_audit_logs" (
    "id" TEXT NOT NULL,
    "notification_id" TEXT NOT NULL,
    "from_status" "NotificationStatus",
    "to_status" "NotificationStatus" NOT NULL,
    "event" TEXT NOT NULL,
    "details" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notification_audit_logs_pkey" PRIMARY KEY ("id")
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS "notifications_status_idx" ON "notifications"("status");
CREATE INDEX IF NOT EXISTS "notifications_channel_idx" ON "notifications"("channel");
CREATE INDEX IF NOT EXISTS "notifications_recipient_idx" ON "notifications"("recipient");
CREATE INDEX IF NOT EXISTS "notifications_created_at_idx" ON "notifications"("created_at");
CREATE INDEX IF NOT EXISTS "notifications_batch_id_idx" ON "notifications"("batch_id");
CREATE INDEX IF NOT EXISTS "notification_audit_logs_notification_id_idx" ON "notification_audit_logs"("notification_id");
CREATE INDEX IF NOT EXISTS "notification_audit_logs_created_at_idx" ON "notification_audit_logs"("created_at");

-- Foreign Keys
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'notifications_batch_id_fkey'
    ) THEN
        ALTER TABLE "notifications" ADD CONSTRAINT "notifications_batch_id_fkey" 
            FOREIGN KEY ("batch_id") REFERENCES "batch_dispatches"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'notification_audit_logs_notification_id_fkey'
    ) THEN
        ALTER TABLE "notification_audit_logs" ADD CONSTRAINT "notification_audit_logs_notification_id_fkey" 
            FOREIGN KEY ("notification_id") REFERENCES "notifications"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
END $$;
