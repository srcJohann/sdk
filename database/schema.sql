--
-- PostgreSQL database dump
--

\restrict u11hooed82mROyaSj32HUgqhzgQtnOsDpDQQfegEajbfr8vfzlK0g6oM37VMaEJ

-- Dumped from database version 16.10 (Ubuntu 16.10-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.10 (Ubuntu 16.10-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: agent_type_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.agent_type_enum AS ENUM (
    'chat_sdr',
    'chat_closer',
    'chat_support'
);


--
-- Name: conversation_status_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.conversation_status_enum AS ENUM (
    'open',
    'pending',
    'resolved',
    'closed',
    'escalated'
);


--
-- Name: lead_status_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.lead_status_enum AS ENUM (
    'new',
    'contacted',
    'qualified',
    'unqualified',
    'converted'
);


--
-- Name: message_role_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.message_role_enum AS ENUM (
    'user',
    'assistant'
);


--
-- Name: user_role_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_role_enum AS ENUM (
    'MASTER',
    'TENANT_ADMIN',
    'TENANT_USER'
);


--
-- Name: current_tenant_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.current_tenant_id() RETURNS integer
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN NULLIF(current_setting('app.current_tenant_id', TRUE), '')::INTEGER;
END;
$$;


--
-- Name: get_global_metrics(timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_global_metrics(p_from_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to_date timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS TABLE(total_tenants bigint, active_tenants bigint, total_inboxes bigint, active_inboxes bigint, total_conversations bigint, open_conversations bigint, total_messages bigint, total_users bigint, active_users bigint, total_input_tokens bigint, total_output_tokens bigint, total_tokens bigint)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT COUNT(*) FROM tenants)::BIGINT as total_tenants,
        (SELECT COUNT(*) FROM tenants WHERE is_active = true)::BIGINT as active_tenants,
        (SELECT COUNT(*) FROM inboxes)::BIGINT as total_inboxes,
        (SELECT COUNT(*) FROM inboxes WHERE is_active = true)::BIGINT as active_inboxes,
        (SELECT COUNT(*) FROM conversations 
         WHERE (p_from_date IS NULL OR created_at >= p_from_date)
           AND (p_to_date IS NULL OR created_at <= p_to_date))::BIGINT as total_conversations,
        (SELECT COUNT(*) FROM conversations WHERE status = 'open')::BIGINT as open_conversations,
        (SELECT COUNT(*) FROM messages
         WHERE (p_from_date IS NULL OR created_at >= p_from_date)
           AND (p_to_date IS NULL OR created_at <= p_to_date))::BIGINT as total_messages,
        (SELECT COUNT(*) FROM users)::BIGINT as total_users,
        (SELECT COUNT(*) FROM users WHERE is_active = true)::BIGINT as active_users,
        (SELECT COALESCE(SUM(input_tokens), 0)::BIGINT FROM messages
         WHERE (p_from_date IS NULL OR created_at >= p_from_date)
           AND (p_to_date IS NULL OR created_at <= p_to_date)) as total_input_tokens,
        (SELECT COALESCE(SUM(output_tokens), 0)::BIGINT FROM messages
         WHERE (p_from_date IS NULL OR created_at >= p_from_date)
           AND (p_to_date IS NULL OR created_at <= p_to_date)) as total_output_tokens,
        (SELECT COALESCE(SUM(input_tokens + output_tokens), 0)::BIGINT FROM messages
         WHERE (p_from_date IS NULL OR created_at >= p_from_date)
           AND (p_to_date IS NULL OR created_at <= p_to_date)) as total_tokens;
END;
$$;


--
-- Name: is_master_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_master_user() RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN current_setting('app.is_master_user', TRUE)::BOOLEAN;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$;


--
-- Name: set_message_index(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_message_index() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.message_index IS NULL THEN
        SELECT COALESCE(MAX(message_index), 0) + 1 INTO NEW.message_index
        FROM messages
        WHERE conversation_id = NEW.conversation_id;
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: update_consumption_daily(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_consumption_daily() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO consumption_inbox_daily (
        tenant_id, inbox_id, date, agent_type,
        total_messages, input_tokens, output_tokens, 
        cached_tokens, session_tokens, total_tokens
    )
    VALUES (
        NEW.tenant_id, NEW.inbox_id, CURRENT_DATE, NEW.agent_type,
        1, NEW.input_tokens, NEW.output_tokens,
        NEW.cached_tokens, NEW.session_tokens,
        NEW.input_tokens + NEW.output_tokens
    )
    ON CONFLICT (tenant_id, inbox_id, date, agent_type) DO UPDATE SET
        total_messages = consumption_inbox_daily.total_messages + 1,
        input_tokens = consumption_inbox_daily.input_tokens + NEW.input_tokens,
        output_tokens = consumption_inbox_daily.output_tokens + NEW.output_tokens,
        cached_tokens = consumption_inbox_daily.cached_tokens + NEW.cached_tokens,
        session_tokens = consumption_inbox_daily.session_tokens + NEW.session_tokens,
        total_tokens = consumption_inbox_daily.total_tokens + NEW.input_tokens + NEW.output_tokens,
        updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_conversation_last_message(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_conversation_last_message() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE conversations
    SET last_message_at = NEW.created_at
    WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$;


--
-- Name: update_lead_status_by_score(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_lead_status_by_score() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.lead_score >= 80 THEN
        NEW.lead_status = 'qualified';
    ELSIF NEW.lead_score >= 50 THEN
        NEW.lead_status = 'contacted';
    ELSIF NEW.lead_score < 30 THEN
        NEW.lead_status = 'unqualified';
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account_vars; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_vars (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    var_name text NOT NULL,
    var_value text NOT NULL,
    var_type text DEFAULT 'string'::text NOT NULL,
    description text,
    is_secret boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE account_vars; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.account_vars IS 'Custom variables per tenant account';


--
-- Name: api_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_logs (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    user_id uuid,
    method text NOT NULL,
    path text NOT NULL,
    status_code integer NOT NULL,
    response_time_ms integer,
    request_body jsonb,
    response_body jsonb,
    error_message text,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
)
PARTITION BY RANGE (created_at);


--
-- Name: TABLE api_logs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.api_logs IS 'API request logs (partitioned by month)';


--
-- Name: api_logs_2025_01; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_logs_2025_01 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    user_id uuid,
    method text NOT NULL,
    path text NOT NULL,
    status_code integer NOT NULL,
    response_time_ms integer,
    request_body jsonb,
    response_body jsonb,
    error_message text,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: api_logs_2025_02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_logs_2025_02 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    user_id uuid,
    method text NOT NULL,
    path text NOT NULL,
    status_code integer NOT NULL,
    response_time_ms integer,
    request_body jsonb,
    response_body jsonb,
    error_message text,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: api_logs_2025_03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_logs_2025_03 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    user_id uuid,
    method text NOT NULL,
    path text NOT NULL,
    status_code integer NOT NULL,
    response_time_ms integer,
    request_body jsonb,
    response_body jsonb,
    error_message text,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: api_logs_2025_04; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_logs_2025_04 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    user_id uuid,
    method text NOT NULL,
    path text NOT NULL,
    status_code integer NOT NULL,
    response_time_ms integer,
    request_body jsonb,
    response_body jsonb,
    error_message text,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: api_logs_2025_05; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_logs_2025_05 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    user_id uuid,
    method text NOT NULL,
    path text NOT NULL,
    status_code integer NOT NULL,
    response_time_ms integer,
    request_body jsonb,
    response_body jsonb,
    error_message text,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: api_logs_2025_06; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_logs_2025_06 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    user_id uuid,
    method text NOT NULL,
    path text NOT NULL,
    status_code integer NOT NULL,
    response_time_ms integer,
    request_body jsonb,
    response_body jsonb,
    error_message text,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: api_logs_2025_07; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_logs_2025_07 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    user_id uuid,
    method text NOT NULL,
    path text NOT NULL,
    status_code integer NOT NULL,
    response_time_ms integer,
    request_body jsonb,
    response_body jsonb,
    error_message text,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: api_logs_2025_08; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_logs_2025_08 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    user_id uuid,
    method text NOT NULL,
    path text NOT NULL,
    status_code integer NOT NULL,
    response_time_ms integer,
    request_body jsonb,
    response_body jsonb,
    error_message text,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: api_logs_2025_09; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_logs_2025_09 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    user_id uuid,
    method text NOT NULL,
    path text NOT NULL,
    status_code integer NOT NULL,
    response_time_ms integer,
    request_body jsonb,
    response_body jsonb,
    error_message text,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: api_logs_2025_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_logs_2025_10 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    user_id uuid,
    method text NOT NULL,
    path text NOT NULL,
    status_code integer NOT NULL,
    response_time_ms integer,
    request_body jsonb,
    response_body jsonb,
    error_message text,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: api_logs_2025_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_logs_2025_11 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    user_id uuid,
    method text NOT NULL,
    path text NOT NULL,
    status_code integer NOT NULL,
    response_time_ms integer,
    request_body jsonb,
    response_body jsonb,
    error_message text,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: api_logs_2025_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_logs_2025_12 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    user_id uuid,
    method text NOT NULL,
    path text NOT NULL,
    status_code integer NOT NULL,
    response_time_ms integer,
    request_body jsonb,
    response_body jsonb,
    error_message text,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    user_id uuid,
    action text NOT NULL,
    resource_type text NOT NULL,
    resource_id text,
    changes jsonb,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
)
PARTITION BY RANGE (created_at);


--
-- Name: TABLE audit_logs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.audit_logs IS 'Audit trail (partitioned by month)';


--
-- Name: audit_logs_2025_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs_2025_10 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    user_id uuid,
    action text NOT NULL,
    resource_type text NOT NULL,
    resource_id text,
    changes jsonb,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: audit_logs_2025_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs_2025_11 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    user_id uuid,
    action text NOT NULL,
    resource_type text NOT NULL,
    resource_id text,
    changes jsonb,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: audit_logs_2025_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs_2025_12 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    user_id uuid,
    action text NOT NULL,
    resource_type text NOT NULL,
    resource_id text,
    changes jsonb,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: consumption_inbox_daily; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.consumption_inbox_daily (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    inbox_id integer NOT NULL,
    date date NOT NULL,
    agent_type public.agent_type_enum NOT NULL,
    total_messages integer DEFAULT 0 NOT NULL,
    input_tokens bigint DEFAULT 0 NOT NULL,
    output_tokens bigint DEFAULT 0 NOT NULL,
    cached_tokens bigint DEFAULT 0 NOT NULL,
    session_tokens bigint DEFAULT 0 NOT NULL,
    total_tokens bigint DEFAULT 0 NOT NULL,
    estimated_cost_usd numeric(10,4) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE consumption_inbox_daily; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.consumption_inbox_daily IS 'Daily consumption metrics per inbox';


--
-- Name: conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversations (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    inbox_id integer NOT NULL,
    external_id text,
    agent_type public.agent_type_enum NOT NULL,
    status public.conversation_status_enum DEFAULT 'open'::public.conversation_status_enum NOT NULL,
    contact_name text,
    contact_phone_e164 text,
    contact_email text,
    contact_external_id text,
    lead_status public.lead_status_enum,
    lead_score integer DEFAULT 0,
    qualification_data jsonb DEFAULT '{}'::jsonb,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    last_message_at timestamp with time zone,
    closed_at timestamp with time zone,
    CONSTRAINT conversations_closed_at_check CHECK (((status = 'closed'::public.conversation_status_enum) OR (closed_at IS NULL))),
    CONSTRAINT conversations_email_format CHECK (((contact_email IS NULL) OR (contact_email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text))),
    CONSTRAINT conversations_lead_score_range CHECK (((lead_score >= 0) AND (lead_score <= 100))),
    CONSTRAINT conversations_phone_format CHECK (((contact_phone_e164 IS NULL) OR (contact_phone_e164 ~ '^\+[1-9]\d{1,14}$'::text)))
);


--
-- Name: TABLE conversations; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.conversations IS 'Conversations between users and AI agents';


--
-- Name: COLUMN conversations.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.conversations.tenant_id IS 'Tenant ID (INTEGER)';


--
-- Name: COLUMN conversations.inbox_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.conversations.inbox_id IS 'Inbox ID (INTEGER)';


--
-- Name: inbox_agents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inbox_agents (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    inbox_id integer NOT NULL,
    agent_type public.agent_type_enum NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    config jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE inbox_agents; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.inbox_agents IS 'Agent configurations per inbox';


--
-- Name: inboxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inboxes (
    id integer NOT NULL,
    tenant_id integer NOT NULL,
    name text NOT NULL,
    chatwoot_inbox_id integer NOT NULL,
    inbox_type text,
    config jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE inboxes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.inboxes IS 'Chatwoot inboxes per tenant';


--
-- Name: COLUMN inboxes.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.inboxes.id IS 'Inbox ID (same as Chatwoot inbox ID)';


--
-- Name: COLUMN inboxes.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.inboxes.tenant_id IS 'Tenant ID (INTEGER)';


--
-- Name: master_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.master_settings (
    id integer DEFAULT 1 NOT NULL,
    sdr_agent_endpoint text DEFAULT 'http://localhost:5000/api/agent/sdr'::text NOT NULL,
    sdr_agent_timeout_ms integer DEFAULT 30000 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    server_config jsonb DEFAULT '{}'::jsonb,
    health_check_enabled boolean DEFAULT true,
    health_check_interval_seconds integer DEFAULT 60,
    health_status text DEFAULT 'unknown'::text,
    last_health_check timestamp with time zone,
    CONSTRAINT only_one_row CHECK ((id = 1))
);


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    conversation_id uuid NOT NULL,
    inbox_id integer NOT NULL,
    message_index integer NOT NULL,
    role public.message_role_enum DEFAULT 'user'::public.message_role_enum NOT NULL,
    user_message text,
    assistant_message text,
    tool_calls jsonb,
    agent_type public.agent_type_enum NOT NULL,
    input_tokens bigint DEFAULT 0 NOT NULL,
    output_tokens bigint DEFAULT 0 NOT NULL,
    cached_tokens bigint DEFAULT 0 NOT NULL,
    session_tokens bigint DEFAULT 0 NOT NULL,
    total_tokens bigint GENERATED ALWAYS AS ((input_tokens + output_tokens)) STORED,
    latency_ms integer,
    model_used text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT messages_content_check CHECK (((user_message IS NOT NULL) OR (assistant_message IS NOT NULL) OR (tool_calls IS NOT NULL))),
    CONSTRAINT messages_message_index_positive CHECK ((message_index > 0)),
    CONSTRAINT messages_tokens_non_negative CHECK (((input_tokens >= 0) AND (output_tokens >= 0) AND (cached_tokens >= 0) AND (session_tokens >= 0)))
)
PARTITION BY RANGE (created_at);


--
-- Name: TABLE messages; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.messages IS 'Messages in conversations (partitioned by month)';


--
-- Name: messages_2025_01; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages_2025_01 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    conversation_id uuid NOT NULL,
    inbox_id integer NOT NULL,
    message_index integer NOT NULL,
    role public.message_role_enum DEFAULT 'user'::public.message_role_enum NOT NULL,
    user_message text,
    assistant_message text,
    tool_calls jsonb,
    agent_type public.agent_type_enum NOT NULL,
    input_tokens bigint DEFAULT 0 NOT NULL,
    output_tokens bigint DEFAULT 0 NOT NULL,
    cached_tokens bigint DEFAULT 0 NOT NULL,
    session_tokens bigint DEFAULT 0 NOT NULL,
    total_tokens bigint GENERATED ALWAYS AS ((input_tokens + output_tokens)) STORED,
    latency_ms integer,
    model_used text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT messages_content_check CHECK (((user_message IS NOT NULL) OR (assistant_message IS NOT NULL) OR (tool_calls IS NOT NULL))),
    CONSTRAINT messages_message_index_positive CHECK ((message_index > 0)),
    CONSTRAINT messages_tokens_non_negative CHECK (((input_tokens >= 0) AND (output_tokens >= 0) AND (cached_tokens >= 0) AND (session_tokens >= 0)))
);


--
-- Name: messages_2025_02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages_2025_02 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    conversation_id uuid NOT NULL,
    inbox_id integer NOT NULL,
    message_index integer NOT NULL,
    role public.message_role_enum DEFAULT 'user'::public.message_role_enum NOT NULL,
    user_message text,
    assistant_message text,
    tool_calls jsonb,
    agent_type public.agent_type_enum NOT NULL,
    input_tokens bigint DEFAULT 0 NOT NULL,
    output_tokens bigint DEFAULT 0 NOT NULL,
    cached_tokens bigint DEFAULT 0 NOT NULL,
    session_tokens bigint DEFAULT 0 NOT NULL,
    total_tokens bigint GENERATED ALWAYS AS ((input_tokens + output_tokens)) STORED,
    latency_ms integer,
    model_used text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT messages_content_check CHECK (((user_message IS NOT NULL) OR (assistant_message IS NOT NULL) OR (tool_calls IS NOT NULL))),
    CONSTRAINT messages_message_index_positive CHECK ((message_index > 0)),
    CONSTRAINT messages_tokens_non_negative CHECK (((input_tokens >= 0) AND (output_tokens >= 0) AND (cached_tokens >= 0) AND (session_tokens >= 0)))
);


--
-- Name: messages_2025_03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages_2025_03 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    conversation_id uuid NOT NULL,
    inbox_id integer NOT NULL,
    message_index integer NOT NULL,
    role public.message_role_enum DEFAULT 'user'::public.message_role_enum NOT NULL,
    user_message text,
    assistant_message text,
    tool_calls jsonb,
    agent_type public.agent_type_enum NOT NULL,
    input_tokens bigint DEFAULT 0 NOT NULL,
    output_tokens bigint DEFAULT 0 NOT NULL,
    cached_tokens bigint DEFAULT 0 NOT NULL,
    session_tokens bigint DEFAULT 0 NOT NULL,
    total_tokens bigint GENERATED ALWAYS AS ((input_tokens + output_tokens)) STORED,
    latency_ms integer,
    model_used text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT messages_content_check CHECK (((user_message IS NOT NULL) OR (assistant_message IS NOT NULL) OR (tool_calls IS NOT NULL))),
    CONSTRAINT messages_message_index_positive CHECK ((message_index > 0)),
    CONSTRAINT messages_tokens_non_negative CHECK (((input_tokens >= 0) AND (output_tokens >= 0) AND (cached_tokens >= 0) AND (session_tokens >= 0)))
);


--
-- Name: messages_2025_04; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages_2025_04 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    conversation_id uuid NOT NULL,
    inbox_id integer NOT NULL,
    message_index integer NOT NULL,
    role public.message_role_enum DEFAULT 'user'::public.message_role_enum NOT NULL,
    user_message text,
    assistant_message text,
    tool_calls jsonb,
    agent_type public.agent_type_enum NOT NULL,
    input_tokens bigint DEFAULT 0 NOT NULL,
    output_tokens bigint DEFAULT 0 NOT NULL,
    cached_tokens bigint DEFAULT 0 NOT NULL,
    session_tokens bigint DEFAULT 0 NOT NULL,
    total_tokens bigint GENERATED ALWAYS AS ((input_tokens + output_tokens)) STORED,
    latency_ms integer,
    model_used text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT messages_content_check CHECK (((user_message IS NOT NULL) OR (assistant_message IS NOT NULL) OR (tool_calls IS NOT NULL))),
    CONSTRAINT messages_message_index_positive CHECK ((message_index > 0)),
    CONSTRAINT messages_tokens_non_negative CHECK (((input_tokens >= 0) AND (output_tokens >= 0) AND (cached_tokens >= 0) AND (session_tokens >= 0)))
);


--
-- Name: messages_2025_05; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages_2025_05 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    conversation_id uuid NOT NULL,
    inbox_id integer NOT NULL,
    message_index integer NOT NULL,
    role public.message_role_enum DEFAULT 'user'::public.message_role_enum NOT NULL,
    user_message text,
    assistant_message text,
    tool_calls jsonb,
    agent_type public.agent_type_enum NOT NULL,
    input_tokens bigint DEFAULT 0 NOT NULL,
    output_tokens bigint DEFAULT 0 NOT NULL,
    cached_tokens bigint DEFAULT 0 NOT NULL,
    session_tokens bigint DEFAULT 0 NOT NULL,
    total_tokens bigint GENERATED ALWAYS AS ((input_tokens + output_tokens)) STORED,
    latency_ms integer,
    model_used text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT messages_content_check CHECK (((user_message IS NOT NULL) OR (assistant_message IS NOT NULL) OR (tool_calls IS NOT NULL))),
    CONSTRAINT messages_message_index_positive CHECK ((message_index > 0)),
    CONSTRAINT messages_tokens_non_negative CHECK (((input_tokens >= 0) AND (output_tokens >= 0) AND (cached_tokens >= 0) AND (session_tokens >= 0)))
);


--
-- Name: messages_2025_06; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages_2025_06 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    conversation_id uuid NOT NULL,
    inbox_id integer NOT NULL,
    message_index integer NOT NULL,
    role public.message_role_enum DEFAULT 'user'::public.message_role_enum NOT NULL,
    user_message text,
    assistant_message text,
    tool_calls jsonb,
    agent_type public.agent_type_enum NOT NULL,
    input_tokens bigint DEFAULT 0 NOT NULL,
    output_tokens bigint DEFAULT 0 NOT NULL,
    cached_tokens bigint DEFAULT 0 NOT NULL,
    session_tokens bigint DEFAULT 0 NOT NULL,
    total_tokens bigint GENERATED ALWAYS AS ((input_tokens + output_tokens)) STORED,
    latency_ms integer,
    model_used text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT messages_content_check CHECK (((user_message IS NOT NULL) OR (assistant_message IS NOT NULL) OR (tool_calls IS NOT NULL))),
    CONSTRAINT messages_message_index_positive CHECK ((message_index > 0)),
    CONSTRAINT messages_tokens_non_negative CHECK (((input_tokens >= 0) AND (output_tokens >= 0) AND (cached_tokens >= 0) AND (session_tokens >= 0)))
);


--
-- Name: messages_2025_07; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages_2025_07 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    conversation_id uuid NOT NULL,
    inbox_id integer NOT NULL,
    message_index integer NOT NULL,
    role public.message_role_enum DEFAULT 'user'::public.message_role_enum NOT NULL,
    user_message text,
    assistant_message text,
    tool_calls jsonb,
    agent_type public.agent_type_enum NOT NULL,
    input_tokens bigint DEFAULT 0 NOT NULL,
    output_tokens bigint DEFAULT 0 NOT NULL,
    cached_tokens bigint DEFAULT 0 NOT NULL,
    session_tokens bigint DEFAULT 0 NOT NULL,
    total_tokens bigint GENERATED ALWAYS AS ((input_tokens + output_tokens)) STORED,
    latency_ms integer,
    model_used text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT messages_content_check CHECK (((user_message IS NOT NULL) OR (assistant_message IS NOT NULL) OR (tool_calls IS NOT NULL))),
    CONSTRAINT messages_message_index_positive CHECK ((message_index > 0)),
    CONSTRAINT messages_tokens_non_negative CHECK (((input_tokens >= 0) AND (output_tokens >= 0) AND (cached_tokens >= 0) AND (session_tokens >= 0)))
);


--
-- Name: messages_2025_08; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages_2025_08 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    conversation_id uuid NOT NULL,
    inbox_id integer NOT NULL,
    message_index integer NOT NULL,
    role public.message_role_enum DEFAULT 'user'::public.message_role_enum NOT NULL,
    user_message text,
    assistant_message text,
    tool_calls jsonb,
    agent_type public.agent_type_enum NOT NULL,
    input_tokens bigint DEFAULT 0 NOT NULL,
    output_tokens bigint DEFAULT 0 NOT NULL,
    cached_tokens bigint DEFAULT 0 NOT NULL,
    session_tokens bigint DEFAULT 0 NOT NULL,
    total_tokens bigint GENERATED ALWAYS AS ((input_tokens + output_tokens)) STORED,
    latency_ms integer,
    model_used text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT messages_content_check CHECK (((user_message IS NOT NULL) OR (assistant_message IS NOT NULL) OR (tool_calls IS NOT NULL))),
    CONSTRAINT messages_message_index_positive CHECK ((message_index > 0)),
    CONSTRAINT messages_tokens_non_negative CHECK (((input_tokens >= 0) AND (output_tokens >= 0) AND (cached_tokens >= 0) AND (session_tokens >= 0)))
);


--
-- Name: messages_2025_09; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages_2025_09 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    conversation_id uuid NOT NULL,
    inbox_id integer NOT NULL,
    message_index integer NOT NULL,
    role public.message_role_enum DEFAULT 'user'::public.message_role_enum NOT NULL,
    user_message text,
    assistant_message text,
    tool_calls jsonb,
    agent_type public.agent_type_enum NOT NULL,
    input_tokens bigint DEFAULT 0 NOT NULL,
    output_tokens bigint DEFAULT 0 NOT NULL,
    cached_tokens bigint DEFAULT 0 NOT NULL,
    session_tokens bigint DEFAULT 0 NOT NULL,
    total_tokens bigint GENERATED ALWAYS AS ((input_tokens + output_tokens)) STORED,
    latency_ms integer,
    model_used text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT messages_content_check CHECK (((user_message IS NOT NULL) OR (assistant_message IS NOT NULL) OR (tool_calls IS NOT NULL))),
    CONSTRAINT messages_message_index_positive CHECK ((message_index > 0)),
    CONSTRAINT messages_tokens_non_negative CHECK (((input_tokens >= 0) AND (output_tokens >= 0) AND (cached_tokens >= 0) AND (session_tokens >= 0)))
);


--
-- Name: messages_2025_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages_2025_10 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    conversation_id uuid NOT NULL,
    inbox_id integer NOT NULL,
    message_index integer NOT NULL,
    role public.message_role_enum DEFAULT 'user'::public.message_role_enum NOT NULL,
    user_message text,
    assistant_message text,
    tool_calls jsonb,
    agent_type public.agent_type_enum NOT NULL,
    input_tokens bigint DEFAULT 0 NOT NULL,
    output_tokens bigint DEFAULT 0 NOT NULL,
    cached_tokens bigint DEFAULT 0 NOT NULL,
    session_tokens bigint DEFAULT 0 NOT NULL,
    total_tokens bigint GENERATED ALWAYS AS ((input_tokens + output_tokens)) STORED,
    latency_ms integer,
    model_used text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT messages_content_check CHECK (((user_message IS NOT NULL) OR (assistant_message IS NOT NULL) OR (tool_calls IS NOT NULL))),
    CONSTRAINT messages_message_index_positive CHECK ((message_index > 0)),
    CONSTRAINT messages_tokens_non_negative CHECK (((input_tokens >= 0) AND (output_tokens >= 0) AND (cached_tokens >= 0) AND (session_tokens >= 0)))
);


--
-- Name: messages_2025_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages_2025_11 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    conversation_id uuid NOT NULL,
    inbox_id integer NOT NULL,
    message_index integer NOT NULL,
    role public.message_role_enum DEFAULT 'user'::public.message_role_enum NOT NULL,
    user_message text,
    assistant_message text,
    tool_calls jsonb,
    agent_type public.agent_type_enum NOT NULL,
    input_tokens bigint DEFAULT 0 NOT NULL,
    output_tokens bigint DEFAULT 0 NOT NULL,
    cached_tokens bigint DEFAULT 0 NOT NULL,
    session_tokens bigint DEFAULT 0 NOT NULL,
    total_tokens bigint GENERATED ALWAYS AS ((input_tokens + output_tokens)) STORED,
    latency_ms integer,
    model_used text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT messages_content_check CHECK (((user_message IS NOT NULL) OR (assistant_message IS NOT NULL) OR (tool_calls IS NOT NULL))),
    CONSTRAINT messages_message_index_positive CHECK ((message_index > 0)),
    CONSTRAINT messages_tokens_non_negative CHECK (((input_tokens >= 0) AND (output_tokens >= 0) AND (cached_tokens >= 0) AND (session_tokens >= 0)))
);


--
-- Name: messages_2025_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages_2025_12 (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    conversation_id uuid NOT NULL,
    inbox_id integer NOT NULL,
    message_index integer NOT NULL,
    role public.message_role_enum DEFAULT 'user'::public.message_role_enum NOT NULL,
    user_message text,
    assistant_message text,
    tool_calls jsonb,
    agent_type public.agent_type_enum NOT NULL,
    input_tokens bigint DEFAULT 0 NOT NULL,
    output_tokens bigint DEFAULT 0 NOT NULL,
    cached_tokens bigint DEFAULT 0 NOT NULL,
    session_tokens bigint DEFAULT 0 NOT NULL,
    total_tokens bigint GENERATED ALWAYS AS ((input_tokens + output_tokens)) STORED,
    latency_ms integer,
    model_used text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT messages_content_check CHECK (((user_message IS NOT NULL) OR (assistant_message IS NOT NULL) OR (tool_calls IS NOT NULL))),
    CONSTRAINT messages_message_index_positive CHECK ((message_index > 0)),
    CONSTRAINT messages_tokens_non_negative CHECK (((input_tokens >= 0) AND (output_tokens >= 0) AND (cached_tokens >= 0) AND (session_tokens >= 0)))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version text NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tenant_inboxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenant_inboxes (
    tenant_id integer NOT NULL,
    inbox_id integer NOT NULL,
    assigned_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: TABLE tenant_inboxes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tenant_inboxes IS 'Many-to-many relationship between tenants and inboxes';


--
-- Name: tenants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenants (
    id integer NOT NULL,
    name text NOT NULL,
    subdomain text,
    chatwoot_account_id integer NOT NULL,
    chatwoot_api_token text,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    slug character varying(255)
);


--
-- Name: TABLE tenants; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tenants IS 'Multi-tenant isolation table. id = chatwoot_account_id';


--
-- Name: COLUMN tenants.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tenants.id IS 'Tenant ID (same as Chatwoot account ID)';


--
-- Name: COLUMN tenants.chatwoot_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tenants.chatwoot_account_id IS 'Chatwoot account ID (same as id)';


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tenant_id integer NOT NULL,
    username text NOT NULL,
    email text NOT NULL,
    password_hash text NOT NULL,
    role public.user_role_enum DEFAULT 'TENANT_USER'::public.user_role_enum NOT NULL,
    full_name text,
    is_active boolean DEFAULT true NOT NULL,
    last_login_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE users; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.users IS 'Users with RBAC roles';


--
-- Name: COLUMN users.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.users.tenant_id IS 'Tenant ID (INTEGER matching Chatwoot account)';


--
-- Name: api_logs_2025_01; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs ATTACH PARTITION public.api_logs_2025_01 FOR VALUES FROM ('2025-01-01 00:00:00+00') TO ('2025-02-01 00:00:00+00');


--
-- Name: api_logs_2025_02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs ATTACH PARTITION public.api_logs_2025_02 FOR VALUES FROM ('2025-02-01 00:00:00+00') TO ('2025-03-01 00:00:00+00');


--
-- Name: api_logs_2025_03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs ATTACH PARTITION public.api_logs_2025_03 FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');


--
-- Name: api_logs_2025_04; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs ATTACH PARTITION public.api_logs_2025_04 FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-05-01 00:00:00+00');


--
-- Name: api_logs_2025_05; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs ATTACH PARTITION public.api_logs_2025_05 FOR VALUES FROM ('2025-05-01 00:00:00+00') TO ('2025-06-01 00:00:00+00');


--
-- Name: api_logs_2025_06; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs ATTACH PARTITION public.api_logs_2025_06 FOR VALUES FROM ('2025-06-01 00:00:00+00') TO ('2025-07-01 00:00:00+00');


--
-- Name: api_logs_2025_07; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs ATTACH PARTITION public.api_logs_2025_07 FOR VALUES FROM ('2025-07-01 00:00:00+00') TO ('2025-08-01 00:00:00+00');


--
-- Name: api_logs_2025_08; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs ATTACH PARTITION public.api_logs_2025_08 FOR VALUES FROM ('2025-08-01 00:00:00+00') TO ('2025-09-01 00:00:00+00');


--
-- Name: api_logs_2025_09; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs ATTACH PARTITION public.api_logs_2025_09 FOR VALUES FROM ('2025-09-01 00:00:00+00') TO ('2025-10-01 00:00:00+00');


--
-- Name: api_logs_2025_10; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs ATTACH PARTITION public.api_logs_2025_10 FOR VALUES FROM ('2025-10-01 00:00:00+00') TO ('2025-11-01 00:00:00+00');


--
-- Name: api_logs_2025_11; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs ATTACH PARTITION public.api_logs_2025_11 FOR VALUES FROM ('2025-11-01 00:00:00+00') TO ('2025-12-01 00:00:00+00');


--
-- Name: api_logs_2025_12; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs ATTACH PARTITION public.api_logs_2025_12 FOR VALUES FROM ('2025-12-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');


--
-- Name: audit_logs_2025_10; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs ATTACH PARTITION public.audit_logs_2025_10 FOR VALUES FROM ('2025-10-01 00:00:00+00') TO ('2025-11-01 00:00:00+00');


--
-- Name: audit_logs_2025_11; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs ATTACH PARTITION public.audit_logs_2025_11 FOR VALUES FROM ('2025-11-01 00:00:00+00') TO ('2025-12-01 00:00:00+00');


--
-- Name: audit_logs_2025_12; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs ATTACH PARTITION public.audit_logs_2025_12 FOR VALUES FROM ('2025-12-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');


--
-- Name: messages_2025_01; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ATTACH PARTITION public.messages_2025_01 FOR VALUES FROM ('2025-01-01 00:00:00+00') TO ('2025-02-01 00:00:00+00');


--
-- Name: messages_2025_02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ATTACH PARTITION public.messages_2025_02 FOR VALUES FROM ('2025-02-01 00:00:00+00') TO ('2025-03-01 00:00:00+00');


--
-- Name: messages_2025_03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ATTACH PARTITION public.messages_2025_03 FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');


--
-- Name: messages_2025_04; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ATTACH PARTITION public.messages_2025_04 FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-05-01 00:00:00+00');


--
-- Name: messages_2025_05; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ATTACH PARTITION public.messages_2025_05 FOR VALUES FROM ('2025-05-01 00:00:00+00') TO ('2025-06-01 00:00:00+00');


--
-- Name: messages_2025_06; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ATTACH PARTITION public.messages_2025_06 FOR VALUES FROM ('2025-06-01 00:00:00+00') TO ('2025-07-01 00:00:00+00');


--
-- Name: messages_2025_07; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ATTACH PARTITION public.messages_2025_07 FOR VALUES FROM ('2025-07-01 00:00:00+00') TO ('2025-08-01 00:00:00+00');


--
-- Name: messages_2025_08; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ATTACH PARTITION public.messages_2025_08 FOR VALUES FROM ('2025-08-01 00:00:00+00') TO ('2025-09-01 00:00:00+00');


--
-- Name: messages_2025_09; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ATTACH PARTITION public.messages_2025_09 FOR VALUES FROM ('2025-09-01 00:00:00+00') TO ('2025-10-01 00:00:00+00');


--
-- Name: messages_2025_10; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ATTACH PARTITION public.messages_2025_10 FOR VALUES FROM ('2025-10-01 00:00:00+00') TO ('2025-11-01 00:00:00+00');


--
-- Name: messages_2025_11; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ATTACH PARTITION public.messages_2025_11 FOR VALUES FROM ('2025-11-01 00:00:00+00') TO ('2025-12-01 00:00:00+00');


--
-- Name: messages_2025_12; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ATTACH PARTITION public.messages_2025_12 FOR VALUES FROM ('2025-12-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');


--
-- Name: account_vars account_vars_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_vars
    ADD CONSTRAINT account_vars_pkey PRIMARY KEY (id);


--
-- Name: account_vars account_vars_tenant_id_var_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_vars
    ADD CONSTRAINT account_vars_tenant_id_var_name_key UNIQUE (tenant_id, var_name);


--
-- Name: api_logs api_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs
    ADD CONSTRAINT api_logs_pkey PRIMARY KEY (id, created_at);


--
-- Name: api_logs_2025_01 api_logs_2025_01_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs_2025_01
    ADD CONSTRAINT api_logs_2025_01_pkey PRIMARY KEY (id, created_at);


--
-- Name: api_logs_2025_02 api_logs_2025_02_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs_2025_02
    ADD CONSTRAINT api_logs_2025_02_pkey PRIMARY KEY (id, created_at);


--
-- Name: api_logs_2025_03 api_logs_2025_03_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs_2025_03
    ADD CONSTRAINT api_logs_2025_03_pkey PRIMARY KEY (id, created_at);


--
-- Name: api_logs_2025_04 api_logs_2025_04_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs_2025_04
    ADD CONSTRAINT api_logs_2025_04_pkey PRIMARY KEY (id, created_at);


--
-- Name: api_logs_2025_05 api_logs_2025_05_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs_2025_05
    ADD CONSTRAINT api_logs_2025_05_pkey PRIMARY KEY (id, created_at);


--
-- Name: api_logs_2025_06 api_logs_2025_06_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs_2025_06
    ADD CONSTRAINT api_logs_2025_06_pkey PRIMARY KEY (id, created_at);


--
-- Name: api_logs_2025_07 api_logs_2025_07_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs_2025_07
    ADD CONSTRAINT api_logs_2025_07_pkey PRIMARY KEY (id, created_at);


--
-- Name: api_logs_2025_08 api_logs_2025_08_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs_2025_08
    ADD CONSTRAINT api_logs_2025_08_pkey PRIMARY KEY (id, created_at);


--
-- Name: api_logs_2025_09 api_logs_2025_09_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs_2025_09
    ADD CONSTRAINT api_logs_2025_09_pkey PRIMARY KEY (id, created_at);


--
-- Name: api_logs_2025_10 api_logs_2025_10_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs_2025_10
    ADD CONSTRAINT api_logs_2025_10_pkey PRIMARY KEY (id, created_at);


--
-- Name: api_logs_2025_11 api_logs_2025_11_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs_2025_11
    ADD CONSTRAINT api_logs_2025_11_pkey PRIMARY KEY (id, created_at);


--
-- Name: api_logs_2025_12 api_logs_2025_12_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_logs_2025_12
    ADD CONSTRAINT api_logs_2025_12_pkey PRIMARY KEY (id, created_at);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id, created_at);


--
-- Name: audit_logs_2025_10 audit_logs_2025_10_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs_2025_10
    ADD CONSTRAINT audit_logs_2025_10_pkey PRIMARY KEY (id, created_at);


--
-- Name: audit_logs_2025_11 audit_logs_2025_11_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs_2025_11
    ADD CONSTRAINT audit_logs_2025_11_pkey PRIMARY KEY (id, created_at);


--
-- Name: audit_logs_2025_12 audit_logs_2025_12_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs_2025_12
    ADD CONSTRAINT audit_logs_2025_12_pkey PRIMARY KEY (id, created_at);


--
-- Name: consumption_inbox_daily consumption_inbox_daily_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consumption_inbox_daily
    ADD CONSTRAINT consumption_inbox_daily_pkey PRIMARY KEY (id);


--
-- Name: consumption_inbox_daily consumption_inbox_daily_tenant_id_inbox_id_date_agent_type_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consumption_inbox_daily
    ADD CONSTRAINT consumption_inbox_daily_tenant_id_inbox_id_date_agent_type_key UNIQUE (tenant_id, inbox_id, date, agent_type);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: inbox_agents inbox_agents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inbox_agents
    ADD CONSTRAINT inbox_agents_pkey PRIMARY KEY (id);


--
-- Name: inbox_agents inbox_agents_unique_agent; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inbox_agents
    ADD CONSTRAINT inbox_agents_unique_agent UNIQUE (inbox_id, agent_type);


--
-- Name: inboxes inboxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inboxes
    ADD CONSTRAINT inboxes_pkey PRIMARY KEY (id);


--
-- Name: inboxes inboxes_tenant_id_chatwoot_inbox_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inboxes
    ADD CONSTRAINT inboxes_tenant_id_chatwoot_inbox_id_key UNIQUE (tenant_id, chatwoot_inbox_id);


--
-- Name: inboxes inboxes_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inboxes
    ADD CONSTRAINT inboxes_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: master_settings master_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.master_settings
    ADD CONSTRAINT master_settings_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id, created_at);


--
-- Name: messages_2025_01 messages_2025_01_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages_2025_01
    ADD CONSTRAINT messages_2025_01_pkey PRIMARY KEY (id, created_at);


--
-- Name: messages_2025_02 messages_2025_02_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages_2025_02
    ADD CONSTRAINT messages_2025_02_pkey PRIMARY KEY (id, created_at);


--
-- Name: messages_2025_03 messages_2025_03_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages_2025_03
    ADD CONSTRAINT messages_2025_03_pkey PRIMARY KEY (id, created_at);


--
-- Name: messages_2025_04 messages_2025_04_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages_2025_04
    ADD CONSTRAINT messages_2025_04_pkey PRIMARY KEY (id, created_at);


--
-- Name: messages_2025_05 messages_2025_05_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages_2025_05
    ADD CONSTRAINT messages_2025_05_pkey PRIMARY KEY (id, created_at);


--
-- Name: messages_2025_06 messages_2025_06_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages_2025_06
    ADD CONSTRAINT messages_2025_06_pkey PRIMARY KEY (id, created_at);


--
-- Name: messages_2025_07 messages_2025_07_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages_2025_07
    ADD CONSTRAINT messages_2025_07_pkey PRIMARY KEY (id, created_at);


--
-- Name: messages_2025_08 messages_2025_08_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages_2025_08
    ADD CONSTRAINT messages_2025_08_pkey PRIMARY KEY (id, created_at);


--
-- Name: messages_2025_09 messages_2025_09_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages_2025_09
    ADD CONSTRAINT messages_2025_09_pkey PRIMARY KEY (id, created_at);


--
-- Name: messages_2025_10 messages_2025_10_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages_2025_10
    ADD CONSTRAINT messages_2025_10_pkey PRIMARY KEY (id, created_at);


--
-- Name: messages_2025_11 messages_2025_11_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages_2025_11
    ADD CONSTRAINT messages_2025_11_pkey PRIMARY KEY (id, created_at);


--
-- Name: messages_2025_12 messages_2025_12_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages_2025_12
    ADD CONSTRAINT messages_2025_12_pkey PRIMARY KEY (id, created_at);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: tenant_inboxes tenant_inboxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_inboxes
    ADD CONSTRAINT tenant_inboxes_pkey PRIMARY KEY (tenant_id, inbox_id);


--
-- Name: tenants tenants_chatwoot_account_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_chatwoot_account_id_key UNIQUE (chatwoot_account_id);


--
-- Name: tenants tenants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_pkey PRIMARY KEY (id);


--
-- Name: tenants tenants_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_slug_key UNIQUE (slug);


--
-- Name: tenants tenants_subdomain_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_subdomain_key UNIQUE (subdomain);


--
-- Name: users users_email_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_unique UNIQUE (tenant_id, email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_unique UNIQUE (tenant_id, username);


--
-- Name: idx_api_logs_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_api_logs_status ON ONLY public.api_logs USING btree (status_code, created_at DESC);


--
-- Name: api_logs_2025_01_status_code_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_01_status_code_created_at_idx ON public.api_logs_2025_01 USING btree (status_code, created_at DESC);


--
-- Name: idx_api_logs_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_api_logs_tenant ON ONLY public.api_logs USING btree (tenant_id, created_at DESC);


--
-- Name: api_logs_2025_01_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_01_tenant_id_created_at_idx ON public.api_logs_2025_01 USING btree (tenant_id, created_at DESC);


--
-- Name: idx_api_logs_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_api_logs_user ON ONLY public.api_logs USING btree (user_id, created_at DESC) WHERE (user_id IS NOT NULL);


--
-- Name: api_logs_2025_01_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_01_user_id_created_at_idx ON public.api_logs_2025_01 USING btree (user_id, created_at DESC) WHERE (user_id IS NOT NULL);


--
-- Name: api_logs_2025_02_status_code_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_02_status_code_created_at_idx ON public.api_logs_2025_02 USING btree (status_code, created_at DESC);


--
-- Name: api_logs_2025_02_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_02_tenant_id_created_at_idx ON public.api_logs_2025_02 USING btree (tenant_id, created_at DESC);


--
-- Name: api_logs_2025_02_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_02_user_id_created_at_idx ON public.api_logs_2025_02 USING btree (user_id, created_at DESC) WHERE (user_id IS NOT NULL);


--
-- Name: api_logs_2025_03_status_code_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_03_status_code_created_at_idx ON public.api_logs_2025_03 USING btree (status_code, created_at DESC);


--
-- Name: api_logs_2025_03_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_03_tenant_id_created_at_idx ON public.api_logs_2025_03 USING btree (tenant_id, created_at DESC);


--
-- Name: api_logs_2025_03_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_03_user_id_created_at_idx ON public.api_logs_2025_03 USING btree (user_id, created_at DESC) WHERE (user_id IS NOT NULL);


--
-- Name: api_logs_2025_04_status_code_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_04_status_code_created_at_idx ON public.api_logs_2025_04 USING btree (status_code, created_at DESC);


--
-- Name: api_logs_2025_04_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_04_tenant_id_created_at_idx ON public.api_logs_2025_04 USING btree (tenant_id, created_at DESC);


--
-- Name: api_logs_2025_04_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_04_user_id_created_at_idx ON public.api_logs_2025_04 USING btree (user_id, created_at DESC) WHERE (user_id IS NOT NULL);


--
-- Name: api_logs_2025_05_status_code_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_05_status_code_created_at_idx ON public.api_logs_2025_05 USING btree (status_code, created_at DESC);


--
-- Name: api_logs_2025_05_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_05_tenant_id_created_at_idx ON public.api_logs_2025_05 USING btree (tenant_id, created_at DESC);


--
-- Name: api_logs_2025_05_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_05_user_id_created_at_idx ON public.api_logs_2025_05 USING btree (user_id, created_at DESC) WHERE (user_id IS NOT NULL);


--
-- Name: api_logs_2025_06_status_code_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_06_status_code_created_at_idx ON public.api_logs_2025_06 USING btree (status_code, created_at DESC);


--
-- Name: api_logs_2025_06_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_06_tenant_id_created_at_idx ON public.api_logs_2025_06 USING btree (tenant_id, created_at DESC);


--
-- Name: api_logs_2025_06_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_06_user_id_created_at_idx ON public.api_logs_2025_06 USING btree (user_id, created_at DESC) WHERE (user_id IS NOT NULL);


--
-- Name: api_logs_2025_07_status_code_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_07_status_code_created_at_idx ON public.api_logs_2025_07 USING btree (status_code, created_at DESC);


--
-- Name: api_logs_2025_07_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_07_tenant_id_created_at_idx ON public.api_logs_2025_07 USING btree (tenant_id, created_at DESC);


--
-- Name: api_logs_2025_07_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_07_user_id_created_at_idx ON public.api_logs_2025_07 USING btree (user_id, created_at DESC) WHERE (user_id IS NOT NULL);


--
-- Name: api_logs_2025_08_status_code_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_08_status_code_created_at_idx ON public.api_logs_2025_08 USING btree (status_code, created_at DESC);


--
-- Name: api_logs_2025_08_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_08_tenant_id_created_at_idx ON public.api_logs_2025_08 USING btree (tenant_id, created_at DESC);


--
-- Name: api_logs_2025_08_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_08_user_id_created_at_idx ON public.api_logs_2025_08 USING btree (user_id, created_at DESC) WHERE (user_id IS NOT NULL);


--
-- Name: api_logs_2025_09_status_code_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_09_status_code_created_at_idx ON public.api_logs_2025_09 USING btree (status_code, created_at DESC);


--
-- Name: api_logs_2025_09_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_09_tenant_id_created_at_idx ON public.api_logs_2025_09 USING btree (tenant_id, created_at DESC);


--
-- Name: api_logs_2025_09_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_09_user_id_created_at_idx ON public.api_logs_2025_09 USING btree (user_id, created_at DESC) WHERE (user_id IS NOT NULL);


--
-- Name: api_logs_2025_10_status_code_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_10_status_code_created_at_idx ON public.api_logs_2025_10 USING btree (status_code, created_at DESC);


--
-- Name: api_logs_2025_10_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_10_tenant_id_created_at_idx ON public.api_logs_2025_10 USING btree (tenant_id, created_at DESC);


--
-- Name: api_logs_2025_10_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_10_user_id_created_at_idx ON public.api_logs_2025_10 USING btree (user_id, created_at DESC) WHERE (user_id IS NOT NULL);


--
-- Name: api_logs_2025_11_status_code_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_11_status_code_created_at_idx ON public.api_logs_2025_11 USING btree (status_code, created_at DESC);


--
-- Name: api_logs_2025_11_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_11_tenant_id_created_at_idx ON public.api_logs_2025_11 USING btree (tenant_id, created_at DESC);


--
-- Name: api_logs_2025_11_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_11_user_id_created_at_idx ON public.api_logs_2025_11 USING btree (user_id, created_at DESC) WHERE (user_id IS NOT NULL);


--
-- Name: api_logs_2025_12_status_code_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_12_status_code_created_at_idx ON public.api_logs_2025_12 USING btree (status_code, created_at DESC);


--
-- Name: api_logs_2025_12_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_12_tenant_id_created_at_idx ON public.api_logs_2025_12 USING btree (tenant_id, created_at DESC);


--
-- Name: api_logs_2025_12_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_logs_2025_12_user_id_created_at_idx ON public.api_logs_2025_12 USING btree (user_id, created_at DESC) WHERE (user_id IS NOT NULL);


--
-- Name: idx_audit_logs_resource; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_logs_resource ON ONLY public.audit_logs USING btree (resource_type, resource_id);


--
-- Name: audit_logs_2025_10_resource_type_resource_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_2025_10_resource_type_resource_id_idx ON public.audit_logs_2025_10 USING btree (resource_type, resource_id);


--
-- Name: idx_audit_logs_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_logs_tenant ON ONLY public.audit_logs USING btree (tenant_id, created_at DESC);


--
-- Name: audit_logs_2025_10_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_2025_10_tenant_id_created_at_idx ON public.audit_logs_2025_10 USING btree (tenant_id, created_at DESC);


--
-- Name: idx_audit_logs_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_logs_user ON ONLY public.audit_logs USING btree (user_id, created_at DESC) WHERE (user_id IS NOT NULL);


--
-- Name: audit_logs_2025_10_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_2025_10_user_id_created_at_idx ON public.audit_logs_2025_10 USING btree (user_id, created_at DESC) WHERE (user_id IS NOT NULL);


--
-- Name: audit_logs_2025_11_resource_type_resource_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_2025_11_resource_type_resource_id_idx ON public.audit_logs_2025_11 USING btree (resource_type, resource_id);


--
-- Name: audit_logs_2025_11_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_2025_11_tenant_id_created_at_idx ON public.audit_logs_2025_11 USING btree (tenant_id, created_at DESC);


--
-- Name: audit_logs_2025_11_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_2025_11_user_id_created_at_idx ON public.audit_logs_2025_11 USING btree (user_id, created_at DESC) WHERE (user_id IS NOT NULL);


--
-- Name: audit_logs_2025_12_resource_type_resource_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_2025_12_resource_type_resource_id_idx ON public.audit_logs_2025_12 USING btree (resource_type, resource_id);


--
-- Name: audit_logs_2025_12_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_2025_12_tenant_id_created_at_idx ON public.audit_logs_2025_12 USING btree (tenant_id, created_at DESC);


--
-- Name: audit_logs_2025_12_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_2025_12_user_id_created_at_idx ON public.audit_logs_2025_12 USING btree (user_id, created_at DESC) WHERE (user_id IS NOT NULL);


--
-- Name: idx_account_vars_secret; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_account_vars_secret ON public.account_vars USING btree (tenant_id, is_secret) WHERE (is_secret = true);


--
-- Name: idx_account_vars_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_account_vars_tenant ON public.account_vars USING btree (tenant_id);


--
-- Name: idx_consumption_inbox_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_consumption_inbox_date ON public.consumption_inbox_daily USING btree (inbox_id, date DESC);


--
-- Name: idx_consumption_tenant_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_consumption_tenant_date ON public.consumption_inbox_daily USING btree (tenant_id, date DESC);


--
-- Name: idx_conversations_agent_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conversations_agent_type ON public.conversations USING btree (tenant_id, agent_type);


--
-- Name: idx_conversations_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conversations_email ON public.conversations USING btree (tenant_id, lower(contact_email)) WHERE (contact_email IS NOT NULL);


--
-- Name: idx_conversations_external; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_conversations_external ON public.conversations USING btree (tenant_id, external_id) WHERE (external_id IS NOT NULL);


--
-- Name: idx_conversations_inbox; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conversations_inbox ON public.conversations USING btree (inbox_id, created_at DESC);


--
-- Name: idx_conversations_lead_score; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conversations_lead_score ON public.conversations USING btree (tenant_id, lead_score DESC) WHERE (lead_score > 0);


--
-- Name: idx_conversations_lead_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conversations_lead_status ON public.conversations USING btree (tenant_id, lead_status) WHERE (lead_status IS NOT NULL);


--
-- Name: idx_conversations_metadata_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conversations_metadata_gin ON public.conversations USING gin (metadata);


--
-- Name: idx_conversations_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conversations_phone ON public.conversations USING btree (tenant_id, contact_phone_e164) WHERE (contact_phone_e164 IS NOT NULL);


--
-- Name: idx_conversations_qualification_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conversations_qualification_gin ON public.conversations USING gin (qualification_data);


--
-- Name: idx_conversations_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conversations_status ON public.conversations USING btree (tenant_id, status) WHERE (status = ANY (ARRAY['open'::public.conversation_status_enum, 'escalated'::public.conversation_status_enum]));


--
-- Name: idx_conversations_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conversations_tenant ON public.conversations USING btree (tenant_id, created_at DESC);


--
-- Name: idx_conversations_tenant_status_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conversations_tenant_status_created ON public.conversations USING btree (tenant_id, status, created_at DESC);


--
-- Name: idx_inbox_agents_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inbox_agents_active ON public.inbox_agents USING btree (tenant_id, is_active) WHERE (is_active = true);


--
-- Name: idx_inbox_agents_inbox; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inbox_agents_inbox ON public.inbox_agents USING btree (inbox_id);


--
-- Name: idx_inbox_agents_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inbox_agents_tenant ON public.inbox_agents USING btree (tenant_id);


--
-- Name: idx_inboxes_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inboxes_active ON public.inboxes USING btree (tenant_id, is_active) WHERE (is_active = true);


--
-- Name: idx_inboxes_chatwoot_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inboxes_chatwoot_id ON public.inboxes USING btree (tenant_id, chatwoot_inbox_id);


--
-- Name: idx_inboxes_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inboxes_tenant ON public.inboxes USING btree (tenant_id);


--
-- Name: idx_messages_agent_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_agent_type ON ONLY public.messages USING btree (tenant_id, agent_type);


--
-- Name: idx_messages_conversation_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_conversation_created ON ONLY public.messages USING btree (conversation_id, created_at);


--
-- Name: idx_messages_conversation_order; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_messages_conversation_order ON ONLY public.messages USING btree (conversation_id, message_index, created_at);


--
-- Name: idx_messages_metadata_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_metadata_gin ON ONLY public.messages USING gin (metadata);


--
-- Name: idx_messages_tenant_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_tenant_created ON ONLY public.messages USING btree (tenant_id, created_at DESC);


--
-- Name: idx_messages_tool_calls_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_tool_calls_gin ON ONLY public.messages USING gin (tool_calls);


--
-- Name: idx_tenants_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tenants_active ON public.tenants USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_tenants_chatwoot_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tenants_chatwoot_id ON public.tenants USING btree (chatwoot_account_id);


--
-- Name: idx_tenants_subdomain; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tenants_subdomain ON public.tenants USING btree (subdomain) WHERE (subdomain IS NOT NULL);


--
-- Name: idx_users_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_active ON public.users USING btree (tenant_id, is_active) WHERE (is_active = true);


--
-- Name: idx_users_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_email ON public.users USING btree (email);


--
-- Name: idx_users_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_role ON public.users USING btree (tenant_id, role);


--
-- Name: idx_users_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_tenant ON public.users USING btree (tenant_id);


--
-- Name: messages_2025_01_conversation_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_01_conversation_id_created_at_idx ON public.messages_2025_01 USING btree (conversation_id, created_at);


--
-- Name: messages_2025_01_conversation_id_message_index_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX messages_2025_01_conversation_id_message_index_created_at_idx ON public.messages_2025_01 USING btree (conversation_id, message_index, created_at);


--
-- Name: messages_2025_01_metadata_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_01_metadata_idx ON public.messages_2025_01 USING gin (metadata);


--
-- Name: messages_2025_01_tenant_id_agent_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_01_tenant_id_agent_type_idx ON public.messages_2025_01 USING btree (tenant_id, agent_type);


--
-- Name: messages_2025_01_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_01_tenant_id_created_at_idx ON public.messages_2025_01 USING btree (tenant_id, created_at DESC);


--
-- Name: messages_2025_01_tool_calls_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_01_tool_calls_idx ON public.messages_2025_01 USING gin (tool_calls);


--
-- Name: messages_2025_02_conversation_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_02_conversation_id_created_at_idx ON public.messages_2025_02 USING btree (conversation_id, created_at);


--
-- Name: messages_2025_02_conversation_id_message_index_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX messages_2025_02_conversation_id_message_index_created_at_idx ON public.messages_2025_02 USING btree (conversation_id, message_index, created_at);


--
-- Name: messages_2025_02_metadata_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_02_metadata_idx ON public.messages_2025_02 USING gin (metadata);


--
-- Name: messages_2025_02_tenant_id_agent_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_02_tenant_id_agent_type_idx ON public.messages_2025_02 USING btree (tenant_id, agent_type);


--
-- Name: messages_2025_02_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_02_tenant_id_created_at_idx ON public.messages_2025_02 USING btree (tenant_id, created_at DESC);


--
-- Name: messages_2025_02_tool_calls_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_02_tool_calls_idx ON public.messages_2025_02 USING gin (tool_calls);


--
-- Name: messages_2025_03_conversation_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_03_conversation_id_created_at_idx ON public.messages_2025_03 USING btree (conversation_id, created_at);


--
-- Name: messages_2025_03_conversation_id_message_index_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX messages_2025_03_conversation_id_message_index_created_at_idx ON public.messages_2025_03 USING btree (conversation_id, message_index, created_at);


--
-- Name: messages_2025_03_metadata_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_03_metadata_idx ON public.messages_2025_03 USING gin (metadata);


--
-- Name: messages_2025_03_tenant_id_agent_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_03_tenant_id_agent_type_idx ON public.messages_2025_03 USING btree (tenant_id, agent_type);


--
-- Name: messages_2025_03_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_03_tenant_id_created_at_idx ON public.messages_2025_03 USING btree (tenant_id, created_at DESC);


--
-- Name: messages_2025_03_tool_calls_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_03_tool_calls_idx ON public.messages_2025_03 USING gin (tool_calls);


--
-- Name: messages_2025_04_conversation_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_04_conversation_id_created_at_idx ON public.messages_2025_04 USING btree (conversation_id, created_at);


--
-- Name: messages_2025_04_conversation_id_message_index_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX messages_2025_04_conversation_id_message_index_created_at_idx ON public.messages_2025_04 USING btree (conversation_id, message_index, created_at);


--
-- Name: messages_2025_04_metadata_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_04_metadata_idx ON public.messages_2025_04 USING gin (metadata);


--
-- Name: messages_2025_04_tenant_id_agent_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_04_tenant_id_agent_type_idx ON public.messages_2025_04 USING btree (tenant_id, agent_type);


--
-- Name: messages_2025_04_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_04_tenant_id_created_at_idx ON public.messages_2025_04 USING btree (tenant_id, created_at DESC);


--
-- Name: messages_2025_04_tool_calls_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_04_tool_calls_idx ON public.messages_2025_04 USING gin (tool_calls);


--
-- Name: messages_2025_05_conversation_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_05_conversation_id_created_at_idx ON public.messages_2025_05 USING btree (conversation_id, created_at);


--
-- Name: messages_2025_05_conversation_id_message_index_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX messages_2025_05_conversation_id_message_index_created_at_idx ON public.messages_2025_05 USING btree (conversation_id, message_index, created_at);


--
-- Name: messages_2025_05_metadata_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_05_metadata_idx ON public.messages_2025_05 USING gin (metadata);


--
-- Name: messages_2025_05_tenant_id_agent_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_05_tenant_id_agent_type_idx ON public.messages_2025_05 USING btree (tenant_id, agent_type);


--
-- Name: messages_2025_05_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_05_tenant_id_created_at_idx ON public.messages_2025_05 USING btree (tenant_id, created_at DESC);


--
-- Name: messages_2025_05_tool_calls_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_05_tool_calls_idx ON public.messages_2025_05 USING gin (tool_calls);


--
-- Name: messages_2025_06_conversation_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_06_conversation_id_created_at_idx ON public.messages_2025_06 USING btree (conversation_id, created_at);


--
-- Name: messages_2025_06_conversation_id_message_index_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX messages_2025_06_conversation_id_message_index_created_at_idx ON public.messages_2025_06 USING btree (conversation_id, message_index, created_at);


--
-- Name: messages_2025_06_metadata_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_06_metadata_idx ON public.messages_2025_06 USING gin (metadata);


--
-- Name: messages_2025_06_tenant_id_agent_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_06_tenant_id_agent_type_idx ON public.messages_2025_06 USING btree (tenant_id, agent_type);


--
-- Name: messages_2025_06_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_06_tenant_id_created_at_idx ON public.messages_2025_06 USING btree (tenant_id, created_at DESC);


--
-- Name: messages_2025_06_tool_calls_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_06_tool_calls_idx ON public.messages_2025_06 USING gin (tool_calls);


--
-- Name: messages_2025_07_conversation_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_07_conversation_id_created_at_idx ON public.messages_2025_07 USING btree (conversation_id, created_at);


--
-- Name: messages_2025_07_conversation_id_message_index_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX messages_2025_07_conversation_id_message_index_created_at_idx ON public.messages_2025_07 USING btree (conversation_id, message_index, created_at);


--
-- Name: messages_2025_07_metadata_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_07_metadata_idx ON public.messages_2025_07 USING gin (metadata);


--
-- Name: messages_2025_07_tenant_id_agent_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_07_tenant_id_agent_type_idx ON public.messages_2025_07 USING btree (tenant_id, agent_type);


--
-- Name: messages_2025_07_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_07_tenant_id_created_at_idx ON public.messages_2025_07 USING btree (tenant_id, created_at DESC);


--
-- Name: messages_2025_07_tool_calls_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_07_tool_calls_idx ON public.messages_2025_07 USING gin (tool_calls);


--
-- Name: messages_2025_08_conversation_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_08_conversation_id_created_at_idx ON public.messages_2025_08 USING btree (conversation_id, created_at);


--
-- Name: messages_2025_08_conversation_id_message_index_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX messages_2025_08_conversation_id_message_index_created_at_idx ON public.messages_2025_08 USING btree (conversation_id, message_index, created_at);


--
-- Name: messages_2025_08_metadata_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_08_metadata_idx ON public.messages_2025_08 USING gin (metadata);


--
-- Name: messages_2025_08_tenant_id_agent_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_08_tenant_id_agent_type_idx ON public.messages_2025_08 USING btree (tenant_id, agent_type);


--
-- Name: messages_2025_08_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_08_tenant_id_created_at_idx ON public.messages_2025_08 USING btree (tenant_id, created_at DESC);


--
-- Name: messages_2025_08_tool_calls_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_08_tool_calls_idx ON public.messages_2025_08 USING gin (tool_calls);


--
-- Name: messages_2025_09_conversation_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_09_conversation_id_created_at_idx ON public.messages_2025_09 USING btree (conversation_id, created_at);


--
-- Name: messages_2025_09_conversation_id_message_index_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX messages_2025_09_conversation_id_message_index_created_at_idx ON public.messages_2025_09 USING btree (conversation_id, message_index, created_at);


--
-- Name: messages_2025_09_metadata_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_09_metadata_idx ON public.messages_2025_09 USING gin (metadata);


--
-- Name: messages_2025_09_tenant_id_agent_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_09_tenant_id_agent_type_idx ON public.messages_2025_09 USING btree (tenant_id, agent_type);


--
-- Name: messages_2025_09_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_09_tenant_id_created_at_idx ON public.messages_2025_09 USING btree (tenant_id, created_at DESC);


--
-- Name: messages_2025_09_tool_calls_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_09_tool_calls_idx ON public.messages_2025_09 USING gin (tool_calls);


--
-- Name: messages_2025_10_conversation_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_10_conversation_id_created_at_idx ON public.messages_2025_10 USING btree (conversation_id, created_at);


--
-- Name: messages_2025_10_conversation_id_message_index_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX messages_2025_10_conversation_id_message_index_created_at_idx ON public.messages_2025_10 USING btree (conversation_id, message_index, created_at);


--
-- Name: messages_2025_10_metadata_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_10_metadata_idx ON public.messages_2025_10 USING gin (metadata);


--
-- Name: messages_2025_10_tenant_id_agent_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_10_tenant_id_agent_type_idx ON public.messages_2025_10 USING btree (tenant_id, agent_type);


--
-- Name: messages_2025_10_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_10_tenant_id_created_at_idx ON public.messages_2025_10 USING btree (tenant_id, created_at DESC);


--
-- Name: messages_2025_10_tool_calls_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_10_tool_calls_idx ON public.messages_2025_10 USING gin (tool_calls);


--
-- Name: messages_2025_11_conversation_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_11_conversation_id_created_at_idx ON public.messages_2025_11 USING btree (conversation_id, created_at);


--
-- Name: messages_2025_11_conversation_id_message_index_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX messages_2025_11_conversation_id_message_index_created_at_idx ON public.messages_2025_11 USING btree (conversation_id, message_index, created_at);


--
-- Name: messages_2025_11_metadata_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_11_metadata_idx ON public.messages_2025_11 USING gin (metadata);


--
-- Name: messages_2025_11_tenant_id_agent_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_11_tenant_id_agent_type_idx ON public.messages_2025_11 USING btree (tenant_id, agent_type);


--
-- Name: messages_2025_11_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_11_tenant_id_created_at_idx ON public.messages_2025_11 USING btree (tenant_id, created_at DESC);


--
-- Name: messages_2025_11_tool_calls_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_11_tool_calls_idx ON public.messages_2025_11 USING gin (tool_calls);


--
-- Name: messages_2025_12_conversation_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_12_conversation_id_created_at_idx ON public.messages_2025_12 USING btree (conversation_id, created_at);


--
-- Name: messages_2025_12_conversation_id_message_index_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX messages_2025_12_conversation_id_message_index_created_at_idx ON public.messages_2025_12 USING btree (conversation_id, message_index, created_at);


--
-- Name: messages_2025_12_metadata_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_12_metadata_idx ON public.messages_2025_12 USING gin (metadata);


--
-- Name: messages_2025_12_tenant_id_agent_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_12_tenant_id_agent_type_idx ON public.messages_2025_12 USING btree (tenant_id, agent_type);


--
-- Name: messages_2025_12_tenant_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_12_tenant_id_created_at_idx ON public.messages_2025_12 USING btree (tenant_id, created_at DESC);


--
-- Name: messages_2025_12_tool_calls_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_2025_12_tool_calls_idx ON public.messages_2025_12 USING gin (tool_calls);


--
-- Name: api_logs_2025_01_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.api_logs_pkey ATTACH PARTITION public.api_logs_2025_01_pkey;


--
-- Name: api_logs_2025_01_status_code_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_status ATTACH PARTITION public.api_logs_2025_01_status_code_created_at_idx;


--
-- Name: api_logs_2025_01_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_tenant ATTACH PARTITION public.api_logs_2025_01_tenant_id_created_at_idx;


--
-- Name: api_logs_2025_01_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_user ATTACH PARTITION public.api_logs_2025_01_user_id_created_at_idx;


--
-- Name: api_logs_2025_02_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.api_logs_pkey ATTACH PARTITION public.api_logs_2025_02_pkey;


--
-- Name: api_logs_2025_02_status_code_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_status ATTACH PARTITION public.api_logs_2025_02_status_code_created_at_idx;


--
-- Name: api_logs_2025_02_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_tenant ATTACH PARTITION public.api_logs_2025_02_tenant_id_created_at_idx;


--
-- Name: api_logs_2025_02_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_user ATTACH PARTITION public.api_logs_2025_02_user_id_created_at_idx;


--
-- Name: api_logs_2025_03_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.api_logs_pkey ATTACH PARTITION public.api_logs_2025_03_pkey;


--
-- Name: api_logs_2025_03_status_code_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_status ATTACH PARTITION public.api_logs_2025_03_status_code_created_at_idx;


--
-- Name: api_logs_2025_03_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_tenant ATTACH PARTITION public.api_logs_2025_03_tenant_id_created_at_idx;


--
-- Name: api_logs_2025_03_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_user ATTACH PARTITION public.api_logs_2025_03_user_id_created_at_idx;


--
-- Name: api_logs_2025_04_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.api_logs_pkey ATTACH PARTITION public.api_logs_2025_04_pkey;


--
-- Name: api_logs_2025_04_status_code_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_status ATTACH PARTITION public.api_logs_2025_04_status_code_created_at_idx;


--
-- Name: api_logs_2025_04_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_tenant ATTACH PARTITION public.api_logs_2025_04_tenant_id_created_at_idx;


--
-- Name: api_logs_2025_04_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_user ATTACH PARTITION public.api_logs_2025_04_user_id_created_at_idx;


--
-- Name: api_logs_2025_05_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.api_logs_pkey ATTACH PARTITION public.api_logs_2025_05_pkey;


--
-- Name: api_logs_2025_05_status_code_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_status ATTACH PARTITION public.api_logs_2025_05_status_code_created_at_idx;


--
-- Name: api_logs_2025_05_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_tenant ATTACH PARTITION public.api_logs_2025_05_tenant_id_created_at_idx;


--
-- Name: api_logs_2025_05_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_user ATTACH PARTITION public.api_logs_2025_05_user_id_created_at_idx;


--
-- Name: api_logs_2025_06_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.api_logs_pkey ATTACH PARTITION public.api_logs_2025_06_pkey;


--
-- Name: api_logs_2025_06_status_code_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_status ATTACH PARTITION public.api_logs_2025_06_status_code_created_at_idx;


--
-- Name: api_logs_2025_06_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_tenant ATTACH PARTITION public.api_logs_2025_06_tenant_id_created_at_idx;


--
-- Name: api_logs_2025_06_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_user ATTACH PARTITION public.api_logs_2025_06_user_id_created_at_idx;


--
-- Name: api_logs_2025_07_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.api_logs_pkey ATTACH PARTITION public.api_logs_2025_07_pkey;


--
-- Name: api_logs_2025_07_status_code_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_status ATTACH PARTITION public.api_logs_2025_07_status_code_created_at_idx;


--
-- Name: api_logs_2025_07_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_tenant ATTACH PARTITION public.api_logs_2025_07_tenant_id_created_at_idx;


--
-- Name: api_logs_2025_07_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_user ATTACH PARTITION public.api_logs_2025_07_user_id_created_at_idx;


--
-- Name: api_logs_2025_08_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.api_logs_pkey ATTACH PARTITION public.api_logs_2025_08_pkey;


--
-- Name: api_logs_2025_08_status_code_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_status ATTACH PARTITION public.api_logs_2025_08_status_code_created_at_idx;


--
-- Name: api_logs_2025_08_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_tenant ATTACH PARTITION public.api_logs_2025_08_tenant_id_created_at_idx;


--
-- Name: api_logs_2025_08_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_user ATTACH PARTITION public.api_logs_2025_08_user_id_created_at_idx;


--
-- Name: api_logs_2025_09_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.api_logs_pkey ATTACH PARTITION public.api_logs_2025_09_pkey;


--
-- Name: api_logs_2025_09_status_code_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_status ATTACH PARTITION public.api_logs_2025_09_status_code_created_at_idx;


--
-- Name: api_logs_2025_09_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_tenant ATTACH PARTITION public.api_logs_2025_09_tenant_id_created_at_idx;


--
-- Name: api_logs_2025_09_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_user ATTACH PARTITION public.api_logs_2025_09_user_id_created_at_idx;


--
-- Name: api_logs_2025_10_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.api_logs_pkey ATTACH PARTITION public.api_logs_2025_10_pkey;


--
-- Name: api_logs_2025_10_status_code_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_status ATTACH PARTITION public.api_logs_2025_10_status_code_created_at_idx;


--
-- Name: api_logs_2025_10_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_tenant ATTACH PARTITION public.api_logs_2025_10_tenant_id_created_at_idx;


--
-- Name: api_logs_2025_10_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_user ATTACH PARTITION public.api_logs_2025_10_user_id_created_at_idx;


--
-- Name: api_logs_2025_11_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.api_logs_pkey ATTACH PARTITION public.api_logs_2025_11_pkey;


--
-- Name: api_logs_2025_11_status_code_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_status ATTACH PARTITION public.api_logs_2025_11_status_code_created_at_idx;


--
-- Name: api_logs_2025_11_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_tenant ATTACH PARTITION public.api_logs_2025_11_tenant_id_created_at_idx;


--
-- Name: api_logs_2025_11_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_user ATTACH PARTITION public.api_logs_2025_11_user_id_created_at_idx;


--
-- Name: api_logs_2025_12_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.api_logs_pkey ATTACH PARTITION public.api_logs_2025_12_pkey;


--
-- Name: api_logs_2025_12_status_code_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_status ATTACH PARTITION public.api_logs_2025_12_status_code_created_at_idx;


--
-- Name: api_logs_2025_12_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_tenant ATTACH PARTITION public.api_logs_2025_12_tenant_id_created_at_idx;


--
-- Name: api_logs_2025_12_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_api_logs_user ATTACH PARTITION public.api_logs_2025_12_user_id_created_at_idx;


--
-- Name: audit_logs_2025_10_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.audit_logs_pkey ATTACH PARTITION public.audit_logs_2025_10_pkey;


--
-- Name: audit_logs_2025_10_resource_type_resource_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_audit_logs_resource ATTACH PARTITION public.audit_logs_2025_10_resource_type_resource_id_idx;


--
-- Name: audit_logs_2025_10_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_audit_logs_tenant ATTACH PARTITION public.audit_logs_2025_10_tenant_id_created_at_idx;


--
-- Name: audit_logs_2025_10_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_audit_logs_user ATTACH PARTITION public.audit_logs_2025_10_user_id_created_at_idx;


--
-- Name: audit_logs_2025_11_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.audit_logs_pkey ATTACH PARTITION public.audit_logs_2025_11_pkey;


--
-- Name: audit_logs_2025_11_resource_type_resource_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_audit_logs_resource ATTACH PARTITION public.audit_logs_2025_11_resource_type_resource_id_idx;


--
-- Name: audit_logs_2025_11_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_audit_logs_tenant ATTACH PARTITION public.audit_logs_2025_11_tenant_id_created_at_idx;


--
-- Name: audit_logs_2025_11_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_audit_logs_user ATTACH PARTITION public.audit_logs_2025_11_user_id_created_at_idx;


--
-- Name: audit_logs_2025_12_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.audit_logs_pkey ATTACH PARTITION public.audit_logs_2025_12_pkey;


--
-- Name: audit_logs_2025_12_resource_type_resource_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_audit_logs_resource ATTACH PARTITION public.audit_logs_2025_12_resource_type_resource_id_idx;


--
-- Name: audit_logs_2025_12_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_audit_logs_tenant ATTACH PARTITION public.audit_logs_2025_12_tenant_id_created_at_idx;


--
-- Name: audit_logs_2025_12_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_audit_logs_user ATTACH PARTITION public.audit_logs_2025_12_user_id_created_at_idx;


--
-- Name: messages_2025_01_conversation_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_created ATTACH PARTITION public.messages_2025_01_conversation_id_created_at_idx;


--
-- Name: messages_2025_01_conversation_id_message_index_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_order ATTACH PARTITION public.messages_2025_01_conversation_id_message_index_created_at_idx;


--
-- Name: messages_2025_01_metadata_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_metadata_gin ATTACH PARTITION public.messages_2025_01_metadata_idx;


--
-- Name: messages_2025_01_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.messages_pkey ATTACH PARTITION public.messages_2025_01_pkey;


--
-- Name: messages_2025_01_tenant_id_agent_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_agent_type ATTACH PARTITION public.messages_2025_01_tenant_id_agent_type_idx;


--
-- Name: messages_2025_01_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tenant_created ATTACH PARTITION public.messages_2025_01_tenant_id_created_at_idx;


--
-- Name: messages_2025_01_tool_calls_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tool_calls_gin ATTACH PARTITION public.messages_2025_01_tool_calls_idx;


--
-- Name: messages_2025_02_conversation_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_created ATTACH PARTITION public.messages_2025_02_conversation_id_created_at_idx;


--
-- Name: messages_2025_02_conversation_id_message_index_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_order ATTACH PARTITION public.messages_2025_02_conversation_id_message_index_created_at_idx;


--
-- Name: messages_2025_02_metadata_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_metadata_gin ATTACH PARTITION public.messages_2025_02_metadata_idx;


--
-- Name: messages_2025_02_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.messages_pkey ATTACH PARTITION public.messages_2025_02_pkey;


--
-- Name: messages_2025_02_tenant_id_agent_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_agent_type ATTACH PARTITION public.messages_2025_02_tenant_id_agent_type_idx;


--
-- Name: messages_2025_02_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tenant_created ATTACH PARTITION public.messages_2025_02_tenant_id_created_at_idx;


--
-- Name: messages_2025_02_tool_calls_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tool_calls_gin ATTACH PARTITION public.messages_2025_02_tool_calls_idx;


--
-- Name: messages_2025_03_conversation_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_created ATTACH PARTITION public.messages_2025_03_conversation_id_created_at_idx;


--
-- Name: messages_2025_03_conversation_id_message_index_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_order ATTACH PARTITION public.messages_2025_03_conversation_id_message_index_created_at_idx;


--
-- Name: messages_2025_03_metadata_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_metadata_gin ATTACH PARTITION public.messages_2025_03_metadata_idx;


--
-- Name: messages_2025_03_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.messages_pkey ATTACH PARTITION public.messages_2025_03_pkey;


--
-- Name: messages_2025_03_tenant_id_agent_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_agent_type ATTACH PARTITION public.messages_2025_03_tenant_id_agent_type_idx;


--
-- Name: messages_2025_03_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tenant_created ATTACH PARTITION public.messages_2025_03_tenant_id_created_at_idx;


--
-- Name: messages_2025_03_tool_calls_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tool_calls_gin ATTACH PARTITION public.messages_2025_03_tool_calls_idx;


--
-- Name: messages_2025_04_conversation_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_created ATTACH PARTITION public.messages_2025_04_conversation_id_created_at_idx;


--
-- Name: messages_2025_04_conversation_id_message_index_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_order ATTACH PARTITION public.messages_2025_04_conversation_id_message_index_created_at_idx;


--
-- Name: messages_2025_04_metadata_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_metadata_gin ATTACH PARTITION public.messages_2025_04_metadata_idx;


--
-- Name: messages_2025_04_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.messages_pkey ATTACH PARTITION public.messages_2025_04_pkey;


--
-- Name: messages_2025_04_tenant_id_agent_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_agent_type ATTACH PARTITION public.messages_2025_04_tenant_id_agent_type_idx;


--
-- Name: messages_2025_04_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tenant_created ATTACH PARTITION public.messages_2025_04_tenant_id_created_at_idx;


--
-- Name: messages_2025_04_tool_calls_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tool_calls_gin ATTACH PARTITION public.messages_2025_04_tool_calls_idx;


--
-- Name: messages_2025_05_conversation_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_created ATTACH PARTITION public.messages_2025_05_conversation_id_created_at_idx;


--
-- Name: messages_2025_05_conversation_id_message_index_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_order ATTACH PARTITION public.messages_2025_05_conversation_id_message_index_created_at_idx;


--
-- Name: messages_2025_05_metadata_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_metadata_gin ATTACH PARTITION public.messages_2025_05_metadata_idx;


--
-- Name: messages_2025_05_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.messages_pkey ATTACH PARTITION public.messages_2025_05_pkey;


--
-- Name: messages_2025_05_tenant_id_agent_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_agent_type ATTACH PARTITION public.messages_2025_05_tenant_id_agent_type_idx;


--
-- Name: messages_2025_05_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tenant_created ATTACH PARTITION public.messages_2025_05_tenant_id_created_at_idx;


--
-- Name: messages_2025_05_tool_calls_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tool_calls_gin ATTACH PARTITION public.messages_2025_05_tool_calls_idx;


--
-- Name: messages_2025_06_conversation_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_created ATTACH PARTITION public.messages_2025_06_conversation_id_created_at_idx;


--
-- Name: messages_2025_06_conversation_id_message_index_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_order ATTACH PARTITION public.messages_2025_06_conversation_id_message_index_created_at_idx;


--
-- Name: messages_2025_06_metadata_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_metadata_gin ATTACH PARTITION public.messages_2025_06_metadata_idx;


--
-- Name: messages_2025_06_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.messages_pkey ATTACH PARTITION public.messages_2025_06_pkey;


--
-- Name: messages_2025_06_tenant_id_agent_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_agent_type ATTACH PARTITION public.messages_2025_06_tenant_id_agent_type_idx;


--
-- Name: messages_2025_06_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tenant_created ATTACH PARTITION public.messages_2025_06_tenant_id_created_at_idx;


--
-- Name: messages_2025_06_tool_calls_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tool_calls_gin ATTACH PARTITION public.messages_2025_06_tool_calls_idx;


--
-- Name: messages_2025_07_conversation_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_created ATTACH PARTITION public.messages_2025_07_conversation_id_created_at_idx;


--
-- Name: messages_2025_07_conversation_id_message_index_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_order ATTACH PARTITION public.messages_2025_07_conversation_id_message_index_created_at_idx;


--
-- Name: messages_2025_07_metadata_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_metadata_gin ATTACH PARTITION public.messages_2025_07_metadata_idx;


--
-- Name: messages_2025_07_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.messages_pkey ATTACH PARTITION public.messages_2025_07_pkey;


--
-- Name: messages_2025_07_tenant_id_agent_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_agent_type ATTACH PARTITION public.messages_2025_07_tenant_id_agent_type_idx;


--
-- Name: messages_2025_07_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tenant_created ATTACH PARTITION public.messages_2025_07_tenant_id_created_at_idx;


--
-- Name: messages_2025_07_tool_calls_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tool_calls_gin ATTACH PARTITION public.messages_2025_07_tool_calls_idx;


--
-- Name: messages_2025_08_conversation_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_created ATTACH PARTITION public.messages_2025_08_conversation_id_created_at_idx;


--
-- Name: messages_2025_08_conversation_id_message_index_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_order ATTACH PARTITION public.messages_2025_08_conversation_id_message_index_created_at_idx;


--
-- Name: messages_2025_08_metadata_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_metadata_gin ATTACH PARTITION public.messages_2025_08_metadata_idx;


--
-- Name: messages_2025_08_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.messages_pkey ATTACH PARTITION public.messages_2025_08_pkey;


--
-- Name: messages_2025_08_tenant_id_agent_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_agent_type ATTACH PARTITION public.messages_2025_08_tenant_id_agent_type_idx;


--
-- Name: messages_2025_08_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tenant_created ATTACH PARTITION public.messages_2025_08_tenant_id_created_at_idx;


--
-- Name: messages_2025_08_tool_calls_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tool_calls_gin ATTACH PARTITION public.messages_2025_08_tool_calls_idx;


--
-- Name: messages_2025_09_conversation_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_created ATTACH PARTITION public.messages_2025_09_conversation_id_created_at_idx;


--
-- Name: messages_2025_09_conversation_id_message_index_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_order ATTACH PARTITION public.messages_2025_09_conversation_id_message_index_created_at_idx;


--
-- Name: messages_2025_09_metadata_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_metadata_gin ATTACH PARTITION public.messages_2025_09_metadata_idx;


--
-- Name: messages_2025_09_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.messages_pkey ATTACH PARTITION public.messages_2025_09_pkey;


--
-- Name: messages_2025_09_tenant_id_agent_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_agent_type ATTACH PARTITION public.messages_2025_09_tenant_id_agent_type_idx;


--
-- Name: messages_2025_09_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tenant_created ATTACH PARTITION public.messages_2025_09_tenant_id_created_at_idx;


--
-- Name: messages_2025_09_tool_calls_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tool_calls_gin ATTACH PARTITION public.messages_2025_09_tool_calls_idx;


--
-- Name: messages_2025_10_conversation_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_created ATTACH PARTITION public.messages_2025_10_conversation_id_created_at_idx;


--
-- Name: messages_2025_10_conversation_id_message_index_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_order ATTACH PARTITION public.messages_2025_10_conversation_id_message_index_created_at_idx;


--
-- Name: messages_2025_10_metadata_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_metadata_gin ATTACH PARTITION public.messages_2025_10_metadata_idx;


--
-- Name: messages_2025_10_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.messages_pkey ATTACH PARTITION public.messages_2025_10_pkey;


--
-- Name: messages_2025_10_tenant_id_agent_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_agent_type ATTACH PARTITION public.messages_2025_10_tenant_id_agent_type_idx;


--
-- Name: messages_2025_10_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tenant_created ATTACH PARTITION public.messages_2025_10_tenant_id_created_at_idx;


--
-- Name: messages_2025_10_tool_calls_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tool_calls_gin ATTACH PARTITION public.messages_2025_10_tool_calls_idx;


--
-- Name: messages_2025_11_conversation_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_created ATTACH PARTITION public.messages_2025_11_conversation_id_created_at_idx;


--
-- Name: messages_2025_11_conversation_id_message_index_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_order ATTACH PARTITION public.messages_2025_11_conversation_id_message_index_created_at_idx;


--
-- Name: messages_2025_11_metadata_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_metadata_gin ATTACH PARTITION public.messages_2025_11_metadata_idx;


--
-- Name: messages_2025_11_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.messages_pkey ATTACH PARTITION public.messages_2025_11_pkey;


--
-- Name: messages_2025_11_tenant_id_agent_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_agent_type ATTACH PARTITION public.messages_2025_11_tenant_id_agent_type_idx;


--
-- Name: messages_2025_11_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tenant_created ATTACH PARTITION public.messages_2025_11_tenant_id_created_at_idx;


--
-- Name: messages_2025_11_tool_calls_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tool_calls_gin ATTACH PARTITION public.messages_2025_11_tool_calls_idx;


--
-- Name: messages_2025_12_conversation_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_created ATTACH PARTITION public.messages_2025_12_conversation_id_created_at_idx;


--
-- Name: messages_2025_12_conversation_id_message_index_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_conversation_order ATTACH PARTITION public.messages_2025_12_conversation_id_message_index_created_at_idx;


--
-- Name: messages_2025_12_metadata_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_metadata_gin ATTACH PARTITION public.messages_2025_12_metadata_idx;


--
-- Name: messages_2025_12_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.messages_pkey ATTACH PARTITION public.messages_2025_12_pkey;


--
-- Name: messages_2025_12_tenant_id_agent_type_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_agent_type ATTACH PARTITION public.messages_2025_12_tenant_id_agent_type_idx;


--
-- Name: messages_2025_12_tenant_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tenant_created ATTACH PARTITION public.messages_2025_12_tenant_id_created_at_idx;


--
-- Name: messages_2025_12_tool_calls_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_messages_tool_calls_gin ATTACH PARTITION public.messages_2025_12_tool_calls_idx;


--
-- Name: account_vars trigger_account_vars_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_account_vars_updated_at BEFORE UPDATE ON public.account_vars FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: consumption_inbox_daily trigger_consumption_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_consumption_updated_at BEFORE UPDATE ON public.consumption_inbox_daily FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: conversations trigger_conversations_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_conversations_updated_at BEFORE UPDATE ON public.conversations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: inbox_agents trigger_inbox_agents_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_inbox_agents_updated_at BEFORE UPDATE ON public.inbox_agents FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: inboxes trigger_inboxes_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_inboxes_updated_at BEFORE UPDATE ON public.inboxes FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: messages trigger_set_message_index; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_set_message_index BEFORE INSERT ON public.messages FOR EACH ROW WHEN ((new.message_index IS NULL)) EXECUTE FUNCTION public.set_message_index();


--
-- Name: tenants trigger_tenants_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_tenants_updated_at BEFORE UPDATE ON public.tenants FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: messages trigger_update_consumption_daily; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_consumption_daily AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.update_consumption_daily();


--
-- Name: messages trigger_update_conversation_last_message; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_conversation_last_message AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.update_conversation_last_message();


--
-- Name: conversations trigger_update_lead_status_by_score; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_lead_status_by_score BEFORE UPDATE OF lead_score ON public.conversations FOR EACH ROW WHEN ((new.lead_score IS DISTINCT FROM old.lead_score)) EXECUTE FUNCTION public.update_lead_status_by_score();


--
-- Name: users trigger_users_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: account_vars account_vars_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_vars
    ADD CONSTRAINT account_vars_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: api_logs api_logs_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.api_logs
    ADD CONSTRAINT api_logs_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: api_logs api_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.api_logs
    ADD CONSTRAINT api_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: audit_logs audit_logs_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.audit_logs
    ADD CONSTRAINT audit_logs_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: audit_logs audit_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.audit_logs
    ADD CONSTRAINT audit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: consumption_inbox_daily consumption_inbox_daily_inbox_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consumption_inbox_daily
    ADD CONSTRAINT consumption_inbox_daily_inbox_id_fkey FOREIGN KEY (inbox_id) REFERENCES public.inboxes(id) ON DELETE CASCADE;


--
-- Name: consumption_inbox_daily consumption_inbox_daily_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consumption_inbox_daily
    ADD CONSTRAINT consumption_inbox_daily_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: conversations conversations_inbox_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_inbox_id_fkey FOREIGN KEY (inbox_id) REFERENCES public.inboxes(id) ON DELETE CASCADE;


--
-- Name: conversations conversations_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: inbox_agents inbox_agents_inbox_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inbox_agents
    ADD CONSTRAINT inbox_agents_inbox_id_fkey FOREIGN KEY (inbox_id) REFERENCES public.inboxes(id) ON DELETE CASCADE;


--
-- Name: inbox_agents inbox_agents_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inbox_agents
    ADD CONSTRAINT inbox_agents_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: inboxes inboxes_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inboxes
    ADD CONSTRAINT inboxes_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: messages messages_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.messages
    ADD CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;


--
-- Name: messages messages_inbox_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.messages
    ADD CONSTRAINT messages_inbox_id_fkey FOREIGN KEY (inbox_id) REFERENCES public.inboxes(id) ON DELETE CASCADE;


--
-- Name: messages messages_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.messages
    ADD CONSTRAINT messages_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: tenant_inboxes tenant_inboxes_inbox_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_inboxes
    ADD CONSTRAINT tenant_inboxes_inbox_id_fkey FOREIGN KEY (inbox_id) REFERENCES public.inboxes(id) ON DELETE CASCADE;


--
-- Name: tenant_inboxes tenant_inboxes_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_inboxes
    ADD CONSTRAINT tenant_inboxes_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: users users_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: account_vars; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.account_vars ENABLE ROW LEVEL SECURITY;

--
-- Name: account_vars account_vars_rbac_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY account_vars_rbac_policy ON public.account_vars USING ((public.is_master_user() OR (tenant_id = public.current_tenant_id())));


--
-- Name: api_logs api_log_rbac_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY api_log_rbac_policy ON public.api_logs USING ((public.is_master_user() OR (tenant_id = public.current_tenant_id())));


--
-- Name: api_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.api_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_logs audit_log_rbac_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_log_rbac_policy ON public.audit_logs USING ((public.is_master_user() OR (tenant_id = public.current_tenant_id())));


--
-- Name: audit_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: consumption_inbox_daily; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.consumption_inbox_daily ENABLE ROW LEVEL SECURITY;

--
-- Name: consumption_inbox_daily consumption_rbac_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY consumption_rbac_policy ON public.consumption_inbox_daily USING ((public.is_master_user() OR (tenant_id = public.current_tenant_id())));


--
-- Name: conversations conversation_rbac_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY conversation_rbac_policy ON public.conversations USING ((public.is_master_user() OR (tenant_id = public.current_tenant_id())));


--
-- Name: conversations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

--
-- Name: inbox_agents; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.inbox_agents ENABLE ROW LEVEL SECURITY;

--
-- Name: inbox_agents inbox_agents_rbac_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY inbox_agents_rbac_policy ON public.inbox_agents USING ((public.is_master_user() OR (tenant_id = public.current_tenant_id())));


--
-- Name: inboxes inbox_rbac_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY inbox_rbac_policy ON public.inboxes USING ((public.is_master_user() OR (tenant_id = public.current_tenant_id())));


--
-- Name: inboxes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.inboxes ENABLE ROW LEVEL SECURITY;

--
-- Name: messages message_rbac_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY message_rbac_policy ON public.messages USING ((public.is_master_user() OR (tenant_id = public.current_tenant_id())));


--
-- Name: messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: tenant_inboxes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tenant_inboxes ENABLE ROW LEVEL SECURITY;

--
-- Name: tenant_inboxes tenant_inboxes_rbac_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_inboxes_rbac_policy ON public.tenant_inboxes USING ((public.is_master_user() OR (tenant_id = public.current_tenant_id())));


--
-- Name: tenants tenant_isolation_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation_policy ON public.tenants USING ((public.is_master_user() OR (id = public.current_tenant_id())));


--
-- Name: tenants; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;

--
-- Name: users user_rbac_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_rbac_policy ON public.users USING ((public.is_master_user() OR (tenant_id = public.current_tenant_id())));


--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

\unrestrict u11hooed82mROyaSj32HUgqhzgQtnOsDpDQQfegEajbfr8vfzlK0g6oM37VMaEJ

