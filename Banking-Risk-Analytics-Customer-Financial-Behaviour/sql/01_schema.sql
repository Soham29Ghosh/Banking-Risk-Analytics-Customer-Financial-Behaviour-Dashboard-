-- =====================================================================
-- Banking Risk Analytics & Customer Financial Behaviour
-- 01_schema.sql : star-style schema (1 fact-like client table + 3 dimensions)
-- Run:  psql -d banking -f sql/01_schema.sql
-- =====================================================================
DROP TABLE IF EXISTS clients, stg_clients, dim_gender, dim_banking_relationship, dim_investment_advisor CASCADE;

CREATE TABLE dim_gender (
    gender_id   SMALLINT PRIMARY KEY,
    gender      VARCHAR(10) NOT NULL
);

CREATE TABLE dim_banking_relationship (
    br_id                 SMALLINT PRIMARY KEY,
    banking_relationship  VARCHAR(30) NOT NULL
);

CREATE TABLE dim_investment_advisor (
    ia_id               SMALLINT PRIMARY KEY,
    investment_advisor  VARCHAR(50) NOT NULL
);

-- Staging table mirrors the raw CSV exactly (dates as text)
CREATE TABLE stg_clients (
    client_id                 VARCHAR(12),
    name                      VARCHAR(60),
    age                       SMALLINT,
    location_id               INTEGER,
    joined_bank               VARCHAR(10),   -- 'DD-MM-YYYY'
    banking_contact           VARCHAR(60),
    nationality               VARCHAR(20),
    occupation                VARCHAR(80),
    fee_structure             VARCHAR(10),
    loyalty_classification    VARCHAR(10),
    estimated_income          NUMERIC(14,2),
    superannuation_savings    NUMERIC(14,2),
    amount_of_credit_cards    SMALLINT,
    credit_card_balance       NUMERIC(14,2),
    bank_loans                NUMERIC(14,2),
    bank_deposits             NUMERIC(14,2),
    checking_accounts         NUMERIC(14,2),
    saving_accounts           NUMERIC(14,2),
    foreign_currency_account  NUMERIC(14,2),
    business_lending          NUMERIC(14,2),
    properties_owned          SMALLINT,
    risk_weighting            SMALLINT,
    br_id                     SMALLINT,
    gender_id                 SMALLINT,
    ia_id                     SMALLINT
);

-- Final client table: surrogate key because client_id is NOT unique in the source
CREATE TABLE clients (
    client_key                SERIAL PRIMARY KEY,
    client_id                 VARCHAR(12) NOT NULL,
    name                      VARCHAR(60),
    age                       SMALLINT CHECK (age BETWEEN 0 AND 120),
    location_id               INTEGER,
    joined_bank               DATE NOT NULL,
    banking_contact           VARCHAR(60),
    nationality               VARCHAR(20),
    occupation                VARCHAR(80),
    fee_structure             VARCHAR(10) CHECK (fee_structure IN ('High','Mid','Low')),
    loyalty_classification    VARCHAR(10),
    estimated_income          NUMERIC(14,2) CHECK (estimated_income >= 0),
    superannuation_savings    NUMERIC(14,2),
    amount_of_credit_cards    SMALLINT,
    credit_card_balance       NUMERIC(14,2),
    bank_loans                NUMERIC(14,2),
    bank_deposits             NUMERIC(14,2),
    checking_accounts         NUMERIC(14,2),
    saving_accounts           NUMERIC(14,2),
    foreign_currency_account  NUMERIC(14,2),
    business_lending          NUMERIC(14,2),
    properties_owned          SMALLINT,
    risk_weighting            SMALLINT CHECK (risk_weighting BETWEEN 1 AND 5),
    br_id                     SMALLINT REFERENCES dim_banking_relationship(br_id),
    gender_id                 SMALLINT REFERENCES dim_gender(gender_id),
    ia_id                     SMALLINT REFERENCES dim_investment_advisor(ia_id)
);

CREATE INDEX idx_clients_client_id ON clients(client_id);
CREATE INDEX idx_clients_br        ON clients(br_id);
CREATE INDEX idx_clients_ia        ON clients(ia_id);

-- Analysis view: all derived metrics in one place (used by 03_analysis_queries.sql)
CREATE OR REPLACE VIEW v_client_metrics AS
SELECT
    c.*,
    g.gender,
    br.banking_relationship,
    ia.investment_advisor,
    c.bank_loans + c.business_lending + c.credit_card_balance                          AS total_loan,
    c.bank_deposits + c.saving_accounts + c.checking_accounts + c.foreign_currency_account AS total_deposit,
    c.bank_loans / NULLIF(c.estimated_income, 0)                                         AS loan_to_income,
    CASE WHEN c.estimated_income < 100000 THEN 'Low'
         WHEN c.estimated_income < 300000 THEN 'Mid'
         ELSE 'High' END                                                                 AS income_band,
    CASE WHEN c.age <= 30 THEN '18-30' WHEN c.age <= 45 THEN '31-45'
         WHEN c.age <= 60 THEN '46-60' ELSE '60+' END                                    AS age_group,
    ROUND(((DATE '2021-12-31' - c.joined_bank) / 365.25)::numeric, 1)                    AS tenure_years,
    CASE c.fee_structure WHEN 'High' THEN 0.05 WHEN 'Mid' THEN 0.03 ELSE 0.01 END        AS processing_fee_rate
FROM clients c
JOIN dim_gender               g  ON g.gender_id = c.gender_id
JOIN dim_banking_relationship br ON br.br_id    = c.br_id
JOIN dim_investment_advisor   ia ON ia.ia_id    = c.ia_id;
