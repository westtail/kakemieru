SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
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
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id bigint NOT NULL,
    category_key character varying,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: category_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_templates (
    id bigint NOT NULL,
    category_key character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: category_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.category_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.category_templates_id_seq OWNED BY public.category_templates.id;


--
-- Name: imports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.imports (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    file_hash character varying NOT NULL,
    imported_at timestamp(6) without time zone,
    payment_method_id bigint NOT NULL,
    row_count integer DEFAULT 0 NOT NULL,
    source_ref character varying,
    source_type character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL,
    CONSTRAINT imports_source_type_check CHECK (((source_type)::text = ANY (ARRAY[('csv'::character varying)::text, ('ocr'::character varying)::text, ('api'::character varying)::text, ('manual_bulk'::character varying)::text])))
);


--
-- Name: imports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.imports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: imports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.imports_id_seq OWNED BY public.imports.id;


--
-- Name: merchant_classifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.merchant_classifications (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    merchant_name character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL,
    category_id bigint NOT NULL
);


--
-- Name: merchant_classifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.merchant_classifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: merchant_classifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.merchant_classifications_id_seq OWNED BY public.merchant_classifications.id;


--
-- Name: payment_methods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_methods (
    id bigint NOT NULL,
    archived_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL,
    payment_type character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL,
    CONSTRAINT payment_methods_payment_type_check CHECK (((payment_type)::text = ANY (ARRAY[('credit'::character varying)::text, ('debit'::character varying)::text, ('e_money'::character varying)::text, ('qr'::character varying)::text, ('cash'::character varying)::text])))
);


--
-- Name: payment_methods_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payment_methods_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_methods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payment_methods_id_seq OWNED BY public.payment_methods.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    ip_address character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sessions_id_seq OWNED BY public.sessions.id;


--
-- Name: solid_cache_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_cache_entries (
    id bigint NOT NULL,
    byte_size integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    key bytea NOT NULL,
    key_hash bigint NOT NULL,
    value bytea NOT NULL
);


--
-- Name: solid_cache_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_cache_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_cache_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_cache_entries_id_seq OWNED BY public.solid_cache_entries.id;


--
-- Name: special_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.special_rules (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    merchant_name character varying NOT NULL,
    amount_min integer,
    amount_max integer,
    day_of_month integer,
    category_id bigint NOT NULL,
    note character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: special_rules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.special_rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: special_rules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.special_rules_id_seq OWNED BY public.special_rules.id;


--
-- Name: transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transactions (
    id bigint NOT NULL,
    amount integer NOT NULL,
    amount_override integer,
    category_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    date date NOT NULL,
    date_override date,
    deleted_at timestamp(6) without time zone,
    description character varying,
    effective_amount integer GENERATED ALWAYS AS (COALESCE(amount_override, amount)) STORED,
    effective_date date GENERATED ALWAYS AS (COALESCE(date_override, date)) STORED,
    import_id bigint,
    merchant_name character varying(255) NOT NULL,
    payment_method_id bigint NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.transactions_id_seq OWNED BY public.transactions.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    admin boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    email_address character varying NOT NULL,
    password_digest character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    auto_apply_merchant_rules_on_import boolean DEFAULT false NOT NULL,
    auto_apply_special_rules_on_import boolean DEFAULT false NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: category_templates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_templates ALTER COLUMN id SET DEFAULT nextval('public.category_templates_id_seq'::regclass);


--
-- Name: imports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imports ALTER COLUMN id SET DEFAULT nextval('public.imports_id_seq'::regclass);


--
-- Name: merchant_classifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merchant_classifications ALTER COLUMN id SET DEFAULT nextval('public.merchant_classifications_id_seq'::regclass);


--
-- Name: payment_methods id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_methods ALTER COLUMN id SET DEFAULT nextval('public.payment_methods_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: solid_cache_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_cache_entries ALTER COLUMN id SET DEFAULT nextval('public.solid_cache_entries_id_seq'::regclass);


--
-- Name: special_rules id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.special_rules ALTER COLUMN id SET DEFAULT nextval('public.special_rules_id_seq'::regclass);


--
-- Name: transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions ALTER COLUMN id SET DEFAULT nextval('public.transactions_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: category_templates category_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_templates
    ADD CONSTRAINT category_templates_pkey PRIMARY KEY (id);


--
-- Name: imports imports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imports
    ADD CONSTRAINT imports_pkey PRIMARY KEY (id);


--
-- Name: merchant_classifications merchant_classifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merchant_classifications
    ADD CONSTRAINT merchant_classifications_pkey PRIMARY KEY (id);


--
-- Name: payment_methods payment_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT payment_methods_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: solid_cache_entries solid_cache_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_cache_entries
    ADD CONSTRAINT solid_cache_entries_pkey PRIMARY KEY (id);


--
-- Name: special_rules special_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.special_rules
    ADD CONSTRAINT special_rules_pkey PRIMARY KEY (id);


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- Name: categories uq_categories_user_id_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT uq_categories_user_id_id UNIQUE (user_id, id);


--
-- Name: payment_methods uq_payment_methods_user_id_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT uq_payment_methods_user_id_id UNIQUE (user_id, id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_categories_on_user_id_and_category_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_categories_on_user_id_and_category_key ON public.categories USING btree (user_id, category_key) WHERE (category_key IS NOT NULL);


--
-- Name: index_categories_on_user_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_categories_on_user_id_and_name ON public.categories USING btree (user_id, name);


--
-- Name: index_category_templates_on_category_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_category_templates_on_category_key ON public.category_templates USING btree (category_key);


--
-- Name: index_imports_on_payment_method_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_imports_on_payment_method_id ON public.imports USING btree (payment_method_id);


--
-- Name: index_imports_on_user_id_and_file_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_imports_on_user_id_and_file_hash ON public.imports USING btree (user_id, file_hash);


--
-- Name: index_merchant_classifications_on_user_id_and_merchant_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_merchant_classifications_on_user_id_and_merchant_name ON public.merchant_classifications USING btree (user_id, merchant_name);


--
-- Name: index_payment_methods_on_user_id_and_archived_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_methods_on_user_id_and_archived_at ON public.payment_methods USING btree (user_id, archived_at);


--
-- Name: index_payment_methods_on_user_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_payment_methods_on_user_id_and_name ON public.payment_methods USING btree (user_id, name);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_solid_cache_entries_on_byte_size; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_cache_entries_on_byte_size ON public.solid_cache_entries USING btree (byte_size);


--
-- Name: index_solid_cache_entries_on_key_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_cache_entries_on_key_hash ON public.solid_cache_entries USING btree (key_hash);


--
-- Name: index_solid_cache_entries_on_key_hash_and_byte_size; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_cache_entries_on_key_hash_and_byte_size ON public.solid_cache_entries USING btree (key_hash, byte_size);


--
-- Name: index_special_rules_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_special_rules_on_user_id ON public.special_rules USING btree (user_id);


--
-- Name: index_special_rules_on_user_id_and_merchant_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_special_rules_on_user_id_and_merchant_name ON public.special_rules USING btree (user_id, merchant_name);


--
-- Name: index_transactions_on_import_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transactions_on_import_id ON public.transactions USING btree (import_id);


--
-- Name: index_transactions_on_user_active_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transactions_on_user_active_category ON public.transactions USING btree (user_id, deleted_at, category_id, effective_date);


--
-- Name: index_transactions_on_user_active_effective_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transactions_on_user_active_effective_date ON public.transactions USING btree (user_id, deleted_at, effective_date);


--
-- Name: index_transactions_on_user_active_payment_method; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transactions_on_user_active_payment_method ON public.transactions USING btree (user_id, deleted_at, payment_method_id);


--
-- Name: index_transactions_on_user_merchant_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transactions_on_user_merchant_name ON public.transactions USING btree (user_id, merchant_name);


--
-- Name: index_users_on_email_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email_address ON public.users USING btree (email_address);


--
-- Name: merchant_classifications fk_merchant_classifications_user_category; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merchant_classifications
    ADD CONSTRAINT fk_merchant_classifications_user_category FOREIGN KEY (user_id, category_id) REFERENCES public.categories(user_id, id) ON DELETE CASCADE;


--
-- Name: transactions fk_rails_13f89a78a2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT fk_rails_13f89a78a2 FOREIGN KEY (import_id) REFERENCES public.imports(id);


--
-- Name: imports fk_rails_321dc501a1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imports
    ADD CONSTRAINT fk_rails_321dc501a1 FOREIGN KEY (payment_method_id) REFERENCES public.payment_methods(id);


--
-- Name: special_rules fk_rails_70504f2e6a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.special_rules
    ADD CONSTRAINT fk_rails_70504f2e6a FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: transactions fk_rails_77364e6416; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT fk_rails_77364e6416 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: merchant_classifications fk_rails_872595a7d4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merchant_classifications
    ADD CONSTRAINT fk_rails_872595a7d4 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: imports fk_rails_b1e2154c26; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imports
    ADD CONSTRAINT fk_rails_b1e2154c26 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: categories fk_rails_b8e2f7adfc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT fk_rails_b8e2f7adfc FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: payment_methods fk_rails_e13d4c515f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT fk_rails_e13d4c515f FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: special_rules fk_special_rules_user_category; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.special_rules
    ADD CONSTRAINT fk_special_rules_user_category FOREIGN KEY (user_id, category_id) REFERENCES public.categories(user_id, id) ON DELETE CASCADE;


--
-- Name: transactions fk_transactions_user_category; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT fk_transactions_user_category FOREIGN KEY (user_id, category_id) REFERENCES public.categories(user_id, id) ON DELETE SET NULL (category_id);


--
-- Name: transactions fk_transactions_user_payment_method; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT fk_transactions_user_payment_method FOREIGN KEY (user_id, payment_method_id) REFERENCES public.payment_methods(user_id, id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260830075001'),
('20260830075000'),
('20260829160216'),
('20260829160215'),
('20260829013729'),
('20260822161835'),
('20260822121953'),
('20260814135612'),
('20260811141411'),
('20260811141410'),
('20260811074455'),
('20260809150454'),
('20260809150453'),
('20260809095119'),
('20260806153956'),
('20260806030604'),
('20260709144944'),
('20260709144943');

