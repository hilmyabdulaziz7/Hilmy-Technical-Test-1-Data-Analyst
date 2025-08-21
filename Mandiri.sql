-- PREPROCESSING DATA
ALTER TABLE public.cards_data
ADD PRIMARY KEY (id);

ALTER TABLE public.cards_data
ADD CONSTRAINT fk_client_id
FOREIGN KEY (client_id) REFERENCES public.users_data(id);

ALTER TABLE public.transactions_data
ADD PRIMARY KEY (id);

ALTER TABLE public.transactions_data
    ADD CONSTRAINT fk_transactions_client
    FOREIGN KEY (client_id) REFERENCES public.users_data(id);
   
ALTER TABLE public.transactions_data
	ADD CONSTRAINT fk_transactions_card
    FOREIGN KEY (card_id) REFERENCES public.cards_data(id);

update users_data 
set 
	per_capita_income = replace(per_capita_income,'$','') ,
	yearly_income = replace(yearly_income ,'$','') ,
	total_debt = replace(total_debt ,'$','');
	
ALTER TABLE public.users_data 
ALTER COLUMN per_capita_income 
TYPE int8 USING per_capita_income::int8;

ALTER TABLE public.users_data 
ALTER COLUMN yearly_income 
TYPE int8 USING yearly_income::int8;

ALTER TABLE public.users_data 
ALTER COLUMN total_debt 
TYPE int8 USING total_debt::int8;

update cards_data 
set credit_limit = replace(credit_limit,'$','');

ALTER TABLE public.cards_data 
ALTER COLUMN credit_limit TYPE int8 
USING credit_limit::int8;

update transactions_data 
set amount = replace(amount ,'$','');

ALTER TABLE public.transactions_data 
ALTER COLUMN amount TYPE numeric 
USING amount::numeric;

ALTER TABLE public.transactions_data 
ALTER COLUMN "date" TYPE timestamp 
USING "date"::timestamp;

-- Total Clients
SELECT
    COUNT(id) AS total_nasabah,
    ROUND(AVG(yearly_income)) AS rata_rata_pendapatan_tahunan,
    ROUND(AVG(credit_score)) AS rata_rata_skor_kredit
FROM
    public.users_data;
    
-- Total Priority Clients
WITH client_financials AS (
    SELECT
        id,
        NTILE(100) OVER (ORDER BY yearly_income DESC) AS income_percentile,
        NTILE(100) OVER (ORDER BY credit_score DESC) AS credit_score_percentile,
        NTILE(100) OVER (ORDER BY total_debt ASC) AS debt_percentile -- Utang lebih rendah lebih baik
    FROM
        public.users_data
)
SELECT
    'Total Nasabah' AS segmen,
    COUNT(id) AS jumlah
FROM public.users_data
UNION ALL
SELECT
    'Calon Nasabah Prioritas' AS segmen,
    COUNT(id) AS jumlah
FROM
    client_financials
WHERE
    income_percentile <= 20 
    AND credit_score_percentile <= 20 
    AND debt_percentile <= 50; 
    
    
-- Priority Client Transaction Profile
WITH priority_clients AS (
    SELECT id
    FROM (
        SELECT
            id,
            NTILE(100) OVER (ORDER BY yearly_income DESC) AS income_percentile,
            NTILE(100) OVER (ORDER BY credit_score DESC) AS credit_score_percentile,
            NTILE(100) OVER (ORDER BY total_debt ASC) AS debt_percentile
        FROM public.users_data
    ) AS client_financials
    WHERE income_percentile <= 20 AND credit_score_percentile <= 20 AND debt_percentile <= 50
)
SELECT
    CASE
        WHEN t.amount < 100 THEN 'Under $100'
        WHEN t.amount >= 100 AND t.amount < 500 THEN '$100 - $500'
        ELSE 'Over $500'
    END AS kelompok_ukuran_transaksi,
    c.card_type, 
    COUNT(t.id) AS jumlah_transaksi
FROM
    public.transactions_data t
JOIN
    priority_clients pc ON t.client_id = pc.id
JOIN 
    public.cards_data c ON t.card_id = c.id
GROUP BY
    kelompok_ukuran_transaksi,
    c.card_type 
ORDER BY
    kelompok_ukuran_transaksi,
    jumlah_transaksi DESC; 
   
-- Top Priority Clients
WITH priority_clients AS (
    SELECT id
    FROM (
        SELECT
            id,
            NTILE(100) OVER (ORDER BY yearly_income DESC) AS income_percentile,
            NTILE(100) OVER (ORDER BY credit_score DESC) AS credit_score_percentile,
            NTILE(100) OVER (ORDER BY total_debt ASC) AS debt_percentile
        FROM public.users_data
    ) AS client_financials
    WHERE income_percentile <= 20 AND credit_score_percentile <= 20 AND debt_percentile <= 50
)
SELECT
    u.id,
    u.yearly_income,
    u.credit_score,
    u.total_debt,
    u.num_credit_cards
FROM public.users_data u
JOIN priority_clients pc ON u.id = pc.id
ORDER BY u.yearly_income DESC
LIMIT 10;