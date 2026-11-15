-- =====================================================================
-- 02_load_data.sql : load raw CSVs (run from the repository root)
-- Run:  psql -d banking -f sql/02_load_data.sql
-- \copy runs client-side, so no superuser rights are needed.
-- =====================================================================
\copy dim_gender               FROM 'data/raw/gender.csv'                 WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy dim_banking_relationship FROM 'data/raw/banking_relationships.csv'  WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy dim_investment_advisor   FROM 'data/raw/investment_advisors.csv'    WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy stg_clients              FROM 'data/raw/Banking.csv'                WITH (FORMAT csv, HEADER true)

INSERT INTO clients (client_id, name, age, location_id, joined_bank, banking_contact, nationality, occupation,
    fee_structure, loyalty_classification, estimated_income, superannuation_savings, amount_of_credit_cards,
    credit_card_balance, bank_loans, bank_deposits, checking_accounts, saving_accounts, foreign_currency_account,
    business_lending, properties_owned, risk_weighting, br_id, gender_id, ia_id)
SELECT client_id, name, age, location_id, TO_DATE(joined_bank, 'DD-MM-YYYY'), banking_contact, nationality, occupation,
    fee_structure, loyalty_classification, estimated_income, superannuation_savings, amount_of_credit_cards,
    credit_card_balance, bank_loans, bank_deposits, checking_accounts, saving_accounts, foreign_currency_account,
    business_lending, properties_owned, risk_weighting, br_id, gender_id, ia_id
FROM stg_clients;

-- Sanity checks
SELECT 'stg rows' AS check, COUNT(*) FROM stg_clients
UNION ALL SELECT 'client rows', COUNT(*) FROM clients
UNION ALL SELECT 'distinct client_id', COUNT(DISTINCT client_id) FROM clients;
