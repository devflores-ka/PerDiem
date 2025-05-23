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

CREATE SCHEMA chats;

ALTER SCHEMA chats OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

CREATE TABLE chats.messages (
    id bigint NOT NULL,
    "createdAt" bigint,
    metadata jsonb,
    duration bigint,
    "mimeType" text,
    name text,
    "remoteId" text,
    "repliedMessage" jsonb,
    "roomId" bigint NOT NULL,
    "showStatus" boolean,
    size bigint,
    status text,
    type text,
    "updatedAt" bigint,
    uri text,
    "waveForm" jsonb,
    "isLoading" boolean,
    height double precision,
    width double precision,
    "previewData" jsonb,
    "authorId" uuid NOT NULL,
    text text
);

ALTER TABLE chats.messages OWNER TO postgres;

ALTER TABLE chats.messages ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME chats.messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

CREATE TABLE chats.rooms (
    id bigint NOT NULL,
    "imageUrl" text,
    metadata jsonb,
    name text,
    type text,
    "userIds" uuid[] NOT NULL,
    "lastMessages" jsonb,
    "userRoles" jsonb,
    "createdAt" bigint NOT NULL,
    "updatedAt" bigint NOT NULL
);

ALTER TABLE chats.rooms OWNER TO postgres;

ALTER TABLE chats.rooms ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME chats.rooms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

CREATE TABLE chats.users (
    "firstName" text,
    "imageUrl" text,
    "lastName" text,
    "descripcion" text,
    metadata jsonb,
    role text,
    id uuid NOT NULL,
    "createdAt" bigint NOT NULL,
    "updatedAt" bigint NOT NULL,
    "lastSeen" bigint NOT NULL
);

ALTER TABLE chats.users OWNER TO postgres;

ALTER TABLE ONLY chats.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);

ALTER TABLE ONLY chats.rooms
    ADD CONSTRAINT rooms_pkey PRIMARY KEY (id);

ALTER TABLE ONLY chats.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);

ALTER TABLE ONLY chats.messages
    ADD CONSTRAINT "messages_authorId_fkey" FOREIGN KEY ("authorId") REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY chats.messages
    ADD CONSTRAINT "messages_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES chats.rooms(id) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE ONLY chats.users
    ADD CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE CASCADE;

CREATE INDEX ON "chats"."messages" USING btree ("authorId");
CREATE INDEX ON "chats"."messages" USING btree ("roomId");

ALTER TABLE chats.messages ENABLE ROW LEVEL SECURITY;

ALTER TABLE chats.rooms ENABLE ROW LEVEL SECURITY;

ALTER TABLE chats.users ENABLE ROW LEVEL SECURITY;

REVOKE USAGE ON SCHEMA chats FROM PUBLIC;
GRANT USAGE ON SCHEMA chats TO anon;
GRANT USAGE ON SCHEMA chats TO authenticated;
GRANT USAGE ON SCHEMA chats TO service_role;

GRANT ALL ON TABLE chats.messages TO anon;
GRANT ALL ON TABLE chats.messages TO authenticated;
GRANT ALL ON TABLE chats.messages TO service_role;

GRANT ALL ON SEQUENCE chats.messages_id_seq TO anon;
GRANT ALL ON SEQUENCE chats.messages_id_seq TO authenticated;
GRANT ALL ON SEQUENCE chats.messages_id_seq TO service_role;

GRANT ALL ON TABLE chats.rooms TO anon;
GRANT ALL ON TABLE chats.rooms TO authenticated;
GRANT ALL ON TABLE chats.rooms TO service_role;

GRANT ALL ON SEQUENCE chats.rooms_id_seq TO anon;
GRANT ALL ON SEQUENCE chats.rooms_id_seq TO authenticated;
GRANT ALL ON SEQUENCE chats.rooms_id_seq TO service_role;

GRANT ALL ON TABLE chats.users TO anon;
GRANT ALL ON TABLE chats.users TO authenticated;
GRANT ALL ON TABLE chats.users TO service_role;

GRANT USAGE ON SCHEMA chats TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA chats TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA chats TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA chats TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA chats GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA chats GRANT ALL ON ROUTINES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA chats GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;

ALTER PUBLICATION supabase_realtime ADD TABLE ONLY chats.messages;

ALTER PUBLICATION supabase_realtime ADD TABLE ONLY chats.rooms;

ALTER PUBLICATION supabase_realtime ADD TABLE ONLY chats.users;