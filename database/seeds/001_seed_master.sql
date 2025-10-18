-- Seed: insert master tenant and master user
-- Assumptions: schema has tenants and users tables as in schema.sql

BEGIN;

-- Insert tenant (id = 1)
-- tenants.chatwoot_account_id is NOT NULL in schema, set it equal to id
INSERT INTO tenants (id, name, chatwoot_account_id, settings, is_active, created_at, updated_at, slug)
VALUES (1, 'DOM360', 1, '{}'::jsonb, TRUE, NOW(), NOW(), 'dom360')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, chatwoot_account_id = EXCLUDED.chatwoot_account_id, updated_at = NOW();

-- Insert or update master user (upsert via DO block to avoid relying on unique constraints)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM users WHERE LOWER(email) = LOWER('master@dom360.com.br')
    ) THEN
        INSERT INTO users (id, tenant_id, role, full_name, username, email, password_hash, is_active, created_at, updated_at)
        VALUES (
            uuid_generate_v4(),
            1,
            'MASTER',
            'Master',
            'Master',
            'master@dom360.com.br',
            '$2b$12$5eu7Wbbqc7bJoZGhnUR3/.bwXmbQnnjV0IdUTJHXYnGaKknPI9BTG',
            TRUE,
            NOW(),
            NOW()
        );
    ELSE
        UPDATE users
        SET password_hash = '$2b$12$5eu7Wbbqc7bJoZGhnUR3/.bwXmbQnnjV0IdUTJHXYnGaKknPI9BTG',
            full_name = 'Master',
            username = 'Master',
            is_active = TRUE,
            updated_at = NOW()
        WHERE LOWER(email) = LOWER('master@dom360.com.br');
    END IF;
END
$$;

COMMIT;

-- Insert default master_settings row if not present
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM master_settings WHERE id = 1) THEN
        INSERT INTO master_settings (
            id, sdr_agent_endpoint, sdr_agent_timeout_ms, server_config,
            health_check_enabled, health_check_interval_seconds, created_at, updated_at
        ) VALUES (
            1,
            'http://localhost:5000/api/agent/sdr',
            30000,
            '{}'::jsonb,
            TRUE,
            60,
            NOW(),
            NOW()
        );
    END IF;
END
$$;
