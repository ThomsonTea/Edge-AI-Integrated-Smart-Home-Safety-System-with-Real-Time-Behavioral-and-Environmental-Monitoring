--
-- PostgreSQL database dump
--

\restrict hJVKP7v1e883wgQ6JczLQ6Dc9z4A8mwrTdeEZv0ZtBl5PJlY6CtDaCzzboe9eSw

-- Dumped from database version 14.23 (Ubuntu 14.23-0ubuntu0.22.04.1)
-- Dumped by pg_dump version 14.23 (Ubuntu 14.23-0ubuntu0.22.04.1)

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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ai_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ai_events (
    id integer NOT NULL,
    premise_id integer,
    profile_id integer,
    event_type character varying(100),
    confidence_score numeric(5,2),
    image_path text,
    "timestamp" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    is_acknowledged boolean DEFAULT false,
    CONSTRAINT check_confidence CHECK (((confidence_score >= (0)::numeric) AND (confidence_score <= (100)::numeric)))
);


ALTER TABLE public.ai_events OWNER TO postgres;

--
-- Name: ai_events_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ai_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ai_events_id_seq OWNER TO postgres;

--
-- Name: ai_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ai_events_id_seq OWNED BY public.ai_events.id;


--
-- Name: devices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.devices (
    id integer NOT NULL,
    premise_id integer,
    device_name character varying(255) NOT NULL,
    device_type character varying(100),
    status boolean,
    stream_url text,
    last_heartbeat timestamp with time zone
);


ALTER TABLE public.devices OWNER TO postgres;

--
-- Name: devices_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.devices_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.devices_id_seq OWNER TO postgres;

--
-- Name: devices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.devices_id_seq OWNED BY public.devices.id;


--
-- Name: notification_routing; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notification_routing (
    id integer NOT NULL,
    profile_id integer,
    alert_type character varying(100),
    whatsapp_number character varying(20),
    twilio_opt_in_status boolean DEFAULT false
);


ALTER TABLE public.notification_routing OWNER TO postgres;

--
-- Name: notification_routing_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.notification_routing_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.notification_routing_id_seq OWNER TO postgres;

--
-- Name: notification_routing_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notification_routing_id_seq OWNED BY public.notification_routing.id;


--
-- Name: premises; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.premises (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    type character varying(100),
    address text
);


ALTER TABLE public.premises OWNER TO postgres;

--
-- Name: premises_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.premises_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.premises_id_seq OWNER TO postgres;

--
-- Name: premises_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.premises_id_seq OWNED BY public.premises.id;


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.profiles (
    id integer NOT NULL,
    premise_id integer,
    username character varying(255) NOT NULL,
    group_type character varying(100),
    hash_password text,
    face_signature text,
    last_seen timestamp with time zone,
    is_blacklisted boolean DEFAULT false,
    email character varying(255),
    phone_number character varying(20)
);


ALTER TABLE public.profiles OWNER TO postgres;

--
-- Name: profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.profiles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.profiles_id_seq OWNER TO postgres;

--
-- Name: profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.profiles_id_seq OWNED BY public.profiles.id;


--
-- Name: system_configs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.system_configs (
    config_key character varying(255) NOT NULL,
    config_value text NOT NULL,
    description text,
    last_updated timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.system_configs OWNER TO postgres;

--
-- Name: ai_events id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ai_events ALTER COLUMN id SET DEFAULT nextval('public.ai_events_id_seq'::regclass);


--
-- Name: devices id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.devices ALTER COLUMN id SET DEFAULT nextval('public.devices_id_seq'::regclass);


--
-- Name: notification_routing id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notification_routing ALTER COLUMN id SET DEFAULT nextval('public.notification_routing_id_seq'::regclass);


--
-- Name: premises id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.premises ALTER COLUMN id SET DEFAULT nextval('public.premises_id_seq'::regclass);


--
-- Name: profiles id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles ALTER COLUMN id SET DEFAULT nextval('public.profiles_id_seq'::regclass);


--
-- Name: ai_events ai_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ai_events
    ADD CONSTRAINT ai_events_pkey PRIMARY KEY (id);


--
-- Name: devices devices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_pkey PRIMARY KEY (id);


--
-- Name: notification_routing notification_routing_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notification_routing
    ADD CONSTRAINT notification_routing_pkey PRIMARY KEY (id);


--
-- Name: premises premises_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.premises
    ADD CONSTRAINT premises_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_email_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_email_unique UNIQUE (email);


--
-- Name: profiles profiles_phone_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_phone_number_key UNIQUE (phone_number);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: system_configs system_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.system_configs
    ADD CONSTRAINT system_configs_pkey PRIMARY KEY (config_key);


--
-- Name: ai_events ai_events_premise_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ai_events
    ADD CONSTRAINT ai_events_premise_id_fkey FOREIGN KEY (premise_id) REFERENCES public.premises(id) ON DELETE CASCADE;


--
-- Name: ai_events ai_events_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ai_events
    ADD CONSTRAINT ai_events_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: devices devices_premise_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_premise_id_fkey FOREIGN KEY (premise_id) REFERENCES public.premises(id) ON DELETE CASCADE;


--
-- Name: notification_routing notification_routing_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notification_routing
    ADD CONSTRAINT notification_routing_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_premise_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_premise_id_fkey FOREIGN KEY (premise_id) REFERENCES public.premises(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

\unrestrict hJVKP7v1e883wgQ6JczLQ6Dc9z4A8mwrTdeEZv0ZtBl5PJlY6CtDaCzzboe9eSw

