\timing on
SET client_min_messages = NOTICE;
SET max_parallel_workers_per_gather = 0;
DROP SCHEMA IF EXISTS magaza CASCADE;
CREATE SCHEMA magaza;
SET search_path TO magaza, public;

DROP TABLE IF EXISTS satis_log;
CREATE TABLE satis_log
(
 id INT,
 musteri_kodu INT,
 mehsul_adi VARCHAR(80),
 kateqoriya VARCHAR(30),
 seher VARCHAR(30),
 status VARCHAR(20),
 miqdar INT,
 mebleg NUMERIC(12, 2),
 tarix DATE
);
INSERT INTO satis_log
SELECT i,
 (random() * 20000)::int + 1,
 'Mehsul ' || (i % 5000),
 (ARRAY['Texnika','Aksesuar','Ofis','Mebel','Kitab'])[(i % 5) + 1],
 (ARRAY['Bakı','Gəncə','Sumqayıt','Şəki','Lənkəran'])[(i % 5) + 1],
 CASE WHEN i % 97 = 0 THEN 'legv' ELSE 'tamam' END,
 (random() * 10)::int + 1,
 (random() * 5000 + 10)::numeric(12, 2),
 DATE '2022-01-01' + (i % 1000)
FROM generate_series(1, 300000) AS i;
ANALYZE satis_log;

-- 1-ci tapşırıq
CREATE TABLE kateqoriya (
    id INTEGER GENERATED ALWAYS AS IDENTITY,
    ad VARCHAR(50) NOT NULL,
    CONSTRAINT pk_kateqoriya PRIMARY KEY (id)
);

-- 2-ci tapşırıq
CREATE TABLE mehsul (
    id INTEGER GENERATED ALWAYS AS IDENTITY,
    ad VARCHAR(100) NOT NULL,
    kateqoriya_id INTEGER,
    qiymet NUMERIC(10, 2) NOT NULL,
    anbarda_say INTEGER,
    aktiv BOOLEAN,
    CONSTRAINT pk_mehsul PRIMARY KEY (id)
);

-- 3-cu tapşırıq
CREATE TABLE musteri (
    id INTEGER GENERATED ALWAYS AS IDENTITY,
    ad VARCHAR(80) NOT NULL,
    soyad VARCHAR(80) NOT NULL,
    email VARCHAR(120) NOT NULL,
    telefon VARCHAR(20),
    qeydiyyat_tarixi DATE,
    CONSTRAINT pk_musteri PRIMARY KEY (id)
);

-- 4-cu tapşırıq
CREATE TABLE sifaris_detal (
    sifaris_id INTEGER NOT NULL,
    mehsul_id INTEGER NOT NULL,
    say INTEGER NOT NULL,
    vahid_qiymet NUMERIC(10, 2) NOT NULL,
    CONSTRAINT pk_sifaris_detal PRIMARY KEY (sifaris_id, mehsul_id)
);

-- 5-ci tapşırıq
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'magaza'
ORDER BY tablename, indexname;

-- 6-ci tapşırıq
ALTER TABLE musteri ADD CONSTRAINT uq_musteri_email UNIQUE (email);
INSERT INTO musteri (ad, soyad, email) VALUES ('Aysel', 'Aliyeva', 'aysel@example.com');
DO $$
BEGIN
    BEGIN
        INSERT INTO musteri (ad, soyad, email) VALUES ('Ayla', 'Aliyeva', 'aysel@example.com');
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE '6: tekrar email redd edildi (23505): %', SQLERRM;
    END;
END $$;

-- 7-ci tapşırıq
INSERT INTO kateqoriya (ad) VALUES ('Texnika'), ('Ofis');
ALTER TABLE mehsul ADD CONSTRAINT uq_mehsul_kateqoriya_ad UNIQUE (kateqoriya_id, ad);
INSERT INTO mehsul (ad, kateqoriya_id, qiymet, aktiv)
VALUES ('Qelem', 1, 2, false), ('Qelem', 2, 2, false);
DO $$
BEGIN
    BEGIN
        INSERT INTO mehsul (ad, kateqoriya_id, qiymet) VALUES ('Qelem', 1, 3);
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE '7: eyni kateqoriyada tekrar ad redd edildi (23505): %', SQLERRM;
    END;
END $$;

-- 8-ci tapşırıq
ALTER TABLE musteri ADD CONSTRAINT uq_musteri_telefon UNIQUE (telefon);
INSERT INTO musteri (ad, soyad, email, telefon)
VALUES ('Nigar', 'Hesenova', 'nigar@example.com', NULL),
       ('Elvin', 'Memmedov', 'elvin@example.com', NULL);
CREATE TEMP TABLE null_telefon_test (
    telefon VARCHAR(20),
    CONSTRAINT uq_null_telefon_test UNIQUE NULLS NOT DISTINCT (telefon)
);
INSERT INTO null_telefon_test VALUES (NULL);
DO $$
BEGIN
    BEGIN
        INSERT INTO null_telefon_test VALUES (NULL);
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE '8: NULLS NOT DISTINCT ikinci NULL-u redd etdi (23505)';
    END;
END $$;
DROP TABLE null_telefon_test;

-- 9-cu tapşırıq
CREATE UNIQUE INDEX idx_mehsul_bir_aktiv ON mehsul (kateqoriya_id) WHERE aktiv IS TRUE;
INSERT INTO mehsul (ad, kateqoriya_id, qiymet, aktiv)
VALUES ('Aktiv 1', 1, 10, true), ('Passiv 1', 1, 10, false), ('Passiv 2', 1, 10, false);
DO $$
BEGIN
    BEGIN
        INSERT INTO mehsul (ad, kateqoriya_id, qiymet, aktiv) VALUES ('Aktiv 2', 1, 10, true);
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE '9: ikinci aktiv mehsul redd edildi (23505)';
    END;
END $$;

-- 10-cu tapşırıq
ALTER TABLE mehsul
    ADD CONSTRAINT chk_mehsul_qiymet CHECK (qiymet > 0),
    ADD CONSTRAINT chk_mehsul_anbar CHECK (anbarda_say >= 0);
DO $$
BEGIN
    BEGIN
        INSERT INTO mehsul (ad, qiymet) VALUES ('Yanlis qiymet', -1);
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE '10: menfi qiymet redd edildi (23514): %', SQLERRM;
    END;
    BEGIN
        INSERT INTO mehsul (ad, qiymet, anbarda_say) VALUES ('Yanlis anbar', 1, -1);
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE '10: menfi stok redd edildi (23514): %', SQLERRM;
    END;
END $$;

-- 11-ci tapşırıq
ALTER TABLE musteri ADD CONSTRAINT chk_musteri_email_format CHECK (
    POSITION('@' IN email) > 0 AND POSITION('.' IN email) > 0
    AND LENGTH(email) > 5 AND POSITION(' ' IN email) = 0
);

-- 12-ci tapşırıq
ALTER TABLE mehsul ADD COLUMN endirimli_qiymet NUMERIC(10, 2);
ALTER TABLE mehsul ADD CONSTRAINT chk_mehsul_endirim
    CHECK (endirimli_qiymet >= 0 AND endirimli_qiymet <= qiymet);

-- 13-cu tapşırıq
CREATE TABLE sifaris (
    id INTEGER GENERATED ALWAYS AS IDENTITY,
    musteri_id INTEGER,
    status VARCHAR(20) NOT NULL,
    legv_sebebi TEXT,
    CONSTRAINT pk_sifaris PRIMARY KEY (id),
    CONSTRAINT chk_sifaris_status CHECK (status IN ('gozleyir', 'gonderilib', 'catdirilib', 'legv')),
    CONSTRAINT chk_sifaris_legv_sebebi CHECK (status <> 'legv' OR legv_sebebi IS NOT NULL)
);

-- 14-cu tapşırıq
INSERT INTO mehsul (ad, qiymet, endirimli_qiymet) VALUES ('NULL test', 20, NULL);
UPDATE mehsul SET endirimli_qiymet = qiymet WHERE endirimli_qiymet IS NULL;
ALTER TABLE mehsul ALTER COLUMN endirimli_qiymet SET NOT NULL;

-- 15-ci tapşırıq
ALTER TABLE musteri ALTER COLUMN qeydiyyat_tarixi SET DEFAULT CURRENT_DATE;
ALTER TABLE mehsul ALTER COLUMN anbarda_say SET DEFAULT 0;
ALTER TABLE mehsul ALTER COLUMN aktiv SET DEFAULT true;
ALTER TABLE sifaris ALTER COLUMN status SET DEFAULT 'gozleyir';

-- 16-ci tapşırıq
INSERT INTO musteri (ad, soyad, email) VALUES ('Leyla', 'Quliyeva', 'leyla@example.com');
INSERT INTO musteri (ad, soyad, email, qeydiyyat_tarixi)
VALUES ('Murad', 'Suleymanov', 'murad@example.com', NULL);
SELECT email, qeydiyyat_tarixi FROM musteri WHERE email IN ('leyla@example.com', 'murad@example.com');

-- 17-ci tapşırıq
ALTER TABLE sifaris_detal ADD COLUMN cemi NUMERIC(12, 2)
    GENERATED ALWAYS AS (say * vahid_qiymet) STORED;
DO $$
BEGIN
    BEGIN
        UPDATE sifaris_detal SET cemi = 50;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '17: hesablanan sutuna UPDATE olmaz (SQLSTATE %): %', SQLSTATE, SQLERRM;
    END;
END $$;

-- 18-ci tapşırıq
ALTER TABLE mehsul ADD CONSTRAINT fk_mehsul_kateqoriya
    FOREIGN KEY (kateqoriya_id) REFERENCES kateqoriya(id);
ALTER TABLE sifaris ADD CONSTRAINT fk_sifaris_musteri
    FOREIGN KEY (musteri_id) REFERENCES musteri(id);
DO $$
BEGIN
    BEGIN
        INSERT INTO mehsul (ad, kateqoriya_id, qiymet, endirimli_qiymet)
        VALUES ('Yad kateqoriya', 9999, 10, 10);
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE '18: olmayan kateqoriyaya istinad redd edildi (23503)';
    END;
END $$;

-- 19-cu tapşırıq
ALTER TABLE mehsul DROP CONSTRAINT fk_mehsul_kateqoriya;
ALTER TABLE mehsul ADD CONSTRAINT fk_mehsul_kateqoriya
    FOREIGN KEY (kateqoriya_id) REFERENCES kateqoriya(id) ON DELETE SET NULL;
ALTER TABLE sifaris_detal ADD CONSTRAINT fk_detal_sifaris
    FOREIGN KEY (sifaris_id) REFERENCES sifaris(id) ON DELETE CASCADE;
ALTER TABLE sifaris_detal ADD CONSTRAINT fk_detal_mehsul
    FOREIGN KEY (mehsul_id) REFERENCES mehsul(id) ON DELETE RESTRICT;
INSERT INTO kateqoriya (ad) VALUES ('Silinecek kateqoriya');
INSERT INTO mehsul (ad, kateqoriya_id, qiymet, endirimli_qiymet)
VALUES ('Silinme testi', 3, 15, 15);
INSERT INTO sifaris (musteri_id) VALUES (1);
INSERT INTO sifaris_detal (sifaris_id, mehsul_id, say, vahid_qiymet) VALUES (1, 1, 2, 2);
DELETE FROM kateqoriya WHERE id = 3;
SELECT ad, kateqoriya_id FROM mehsul WHERE ad = 'Silinme testi';
DO $$
BEGIN
    BEGIN
        DELETE FROM mehsul WHERE id = 1;
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE '19: RESTRICT bagli mehsulun silinmesini blokladi (23503)';
    END;
END $$;
DELETE FROM sifaris WHERE id = 1;
SELECT COUNT(*) AS qalan_detal FROM sifaris_detal WHERE sifaris_id = 1;

-- 20-ci tapşırıq
ALTER TABLE musteri ADD COLUMN devet_eden_id INTEGER;
ALTER TABLE musteri ADD CONSTRAINT fk_musteri_devet_eden
    FOREIGN KEY (devet_eden_id) REFERENCES musteri(id) DEFERRABLE INITIALLY DEFERRED;
BEGIN;
INSERT INTO musteri (id, ad, soyad, email, devet_eden_id)
OVERRIDING SYSTEM VALUE VALUES (1001, 'A', 'Test', 'a1001@example.com', 1002);
INSERT INTO musteri (id, ad, soyad, email, devet_eden_id)
OVERRIDING SYSTEM VALUE VALUES (1002, 'B', 'Test', 'b1002@example.com', 1001);
COMMIT;
SELECT id, devet_eden_id FROM musteri WHERE id IN (1001, 1002);

-- 21-ci tapşırıq
INSERT INTO mehsul (ad, qiymet, anbarda_say, endirimli_qiymet)
VALUES ('Bos stok testi', 10, NULL, 10);
SELECT id, ad FROM mehsul WHERE anbarda_say IS NULL;
UPDATE mehsul SET anbarda_say = 0 WHERE anbarda_say IS NULL;
ALTER TABLE mehsul ALTER COLUMN anbarda_say SET NOT NULL;

-- 22-ci tapşırıq
ALTER TABLE mehsul
    DROP CONSTRAINT chk_mehsul_qiymet,
    ADD CONSTRAINT chk_mehsul_qiymet CHECK (qiymet > 0 AND qiymet < 100000);

-- 23-cu tapşırıq
INSERT INTO mehsul (ad, qiymet, endirimli_qiymet) VALUES ('', 10, 10);
ALTER TABLE mehsul ADD CONSTRAINT chk_mehsul_ad_bos_deyil CHECK (ad <> '') NOT VALID;
DO $$
BEGIN
    BEGIN
        INSERT INTO mehsul (ad, qiymet, endirimli_qiymet) VALUES ('', 11, 11);
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE '23: NOT VALID yeni sehvi redd etdi (23514)';
    END;
END $$;
UPDATE mehsul SET ad = 'Duzeldilmis ad' WHERE ad = '';
ALTER TABLE mehsul VALIDATE CONSTRAINT chk_mehsul_ad_bos_deyil;

-- 24-cu tapşırıq
BEGIN;
ALTER TABLE sifaris DROP CONSTRAINT fk_sifaris_musteri;
INSERT INTO sifaris (musteri_id) VALUES (1);
ALTER TABLE sifaris ADD CONSTRAINT fk_sifaris_musteri
    FOREIGN KEY (musteri_id) REFERENCES musteri(id) NOT VALID;
ALTER TABLE sifaris VALIDATE CONSTRAINT fk_sifaris_musteri;
ROLLBACK;
BEGIN;
SET CONSTRAINTS fk_musteri_devet_eden DEFERRED;
INSERT INTO musteri (id, ad, soyad, email, devet_eden_id)
OVERRIDING SYSTEM VALUE VALUES (2001, 'C', 'Test', 'c2001@example.com', 2002);
INSERT INTO musteri (id, ad, soyad, email, devet_eden_id)
OVERRIDING SYSTEM VALUE VALUES (2002, 'D', 'Test', 'd2002@example.com', 2001);
COMMIT;

-- 25-ci tapşırıq
SELECT c.conrelid::regclass AS cedvel, c.conname AS ad,
       CASE c.contype WHEN 'p' THEN 'Esas acar' WHEN 'u' THEN 'Tekrarsiz'
            WHEN 'c' THEN 'Yoxlama' WHEN 'f' THEN 'Xarici acar' END AS tip,
       pg_get_constraintdef(c.oid) AS terif
FROM pg_constraint AS c
JOIN pg_namespace AS n ON n.oid = c.connamespace
WHERE n.nspname = 'magaza' AND c.contype IN ('p', 'u', 'c', 'f')
ORDER BY c.conrelid::regclass::text, c.conname;

-- 26-ci tapşırıq
\echo '26: indeksden evvel'
ANALYZE satis_log;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM satis_log WHERE mehsul_adi = 'Mehsul 4321';
CREATE INDEX idx_satis_log_mehsul_adi ON satis_log (mehsul_adi);
\echo '26: indeksden sonra'
ANALYZE satis_log;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM satis_log WHERE mehsul_adi = 'Mehsul 4321';

-- 27-ci tapşırıq
CREATE INDEX idx_satis_log_kateqoriya_tarix ON satis_log (kateqoriya, tarix);
\echo '27a: kateqoriya'
ANALYZE satis_log;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM satis_log WHERE kateqoriya = 'Ofis';
\echo '27b: tarix'
ANALYZE satis_log;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM satis_log WHERE tarix = DATE '2022-01-02';
\echo '27c: her ikisi'
ANALYZE satis_log;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM satis_log
WHERE kateqoriya = 'Ofis' AND tarix = DATE '2022-01-03';

-- 28-ci tapşırıq
ALTER TABLE satis_log ADD CONSTRAINT uq_satis_log_id UNIQUE (id);
CREATE UNIQUE INDEX idx_satis_log_id_musteri ON satis_log (id, musteri_kodu);
SELECT c.conname, c.contype, i.indexname
FROM pg_constraint AS c
JOIN pg_class AS t ON t.oid = c.conrelid
LEFT JOIN pg_indexes AS i ON i.schemaname = 'magaza' AND i.indexname = c.conname
WHERE t.oid = 'magaza.satis_log'::regclass AND c.conname = 'uq_satis_log_id';
SELECT indexname FROM pg_indexes WHERE schemaname = 'magaza'
AND tablename = 'satis_log' AND indexname IN ('uq_satis_log_id', 'idx_satis_log_id_musteri');
ALTER TABLE satis_log DROP CONSTRAINT uq_satis_log_id;
DO $$
BEGIN
    BEGIN
        ALTER TABLE satis_log DROP CONSTRAINT idx_satis_log_id_musteri;
    EXCEPTION WHEN undefined_object THEN
        RAISE NOTICE '28: musteqil indeksi DROP CONSTRAINT ile silmek olmaz (42704)';
    END;
END $$;
DROP INDEX idx_satis_log_id_musteri;

-- 29-cu tapşırıq
CREATE INDEX idx_satis_log_status_tam ON satis_log (status);
\echo '29: tam indeks'
ANALYZE satis_log;
SELECT pg_size_pretty(pg_relation_size('idx_satis_log_status_tam')) AS indeks_olcusu;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM satis_log WHERE status = 'legv';
DROP INDEX idx_satis_log_status_tam;
CREATE INDEX idx_satis_log_status_legv ON satis_log (status) WHERE status = 'legv';
\echo '29: partial indeks'
ANALYZE satis_log;
SELECT pg_size_pretty(pg_relation_size('idx_satis_log_status_legv')) AS indeks_olcusu;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM satis_log WHERE status = 'legv';

-- 30-cu tapşırıq
\echo '30: funksiya ve sade indeks'
ANALYZE satis_log;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM satis_log
WHERE UPPER(mehsul_adi) = 'MEHSUL 100';
\echo '30: sade muqayise'
ANALYZE satis_log;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM satis_log WHERE mehsul_adi = 'Mehsul 100';
CREATE INDEX idx_satis_log_upper_mehsul ON satis_log (UPPER(mehsul_adi));
\echo '30: ifade indeksi'
ANALYZE satis_log;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM satis_log
WHERE UPPER(mehsul_adi) = 'MEHSUL 100';

-- 31-ci tapşırıq
CREATE INDEX idx_satis_log_seher_include_tarix ON satis_log (seher) INCLUDE (tarix);
VACUUM satis_log;
\echo '31: index only scan ve heap fetches'
ANALYZE satis_log;
EXPLAIN (ANALYZE, BUFFERS) SELECT seher, tarix FROM satis_log WHERE seher = 'Gəncə';

-- 32-ci tapşırıq
CREATE INDEX idx_satis_log_mebleg_desc ON satis_log (mebleg DESC);
\echo '32a: DESC'
ANALYZE satis_log;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM satis_log ORDER BY mebleg DESC LIMIT 20;
CREATE INDEX idx_satis_log_mebleg_desc_nulls_last ON satis_log (mebleg DESC NULLS LAST);
\echo '32b: DESC NULLS LAST'
ANALYZE satis_log;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM satis_log ORDER BY mebleg DESC NULLS LAST LIMIT 20;

-- 33-cu tapşırıq
ANALYZE satis_log;
SELECT indexname, pg_size_pretty(pg_relation_size((schemaname || '.' || indexname)::regclass)) AS olcu,
       ROUND(100.0 * pg_relation_size((schemaname || '.' || indexname)::regclass)
             / NULLIF(pg_relation_size('magaza.satis_log'), 0), 1) AS cedvele_nisbet_faiz,
       indexdef
FROM pg_indexes
WHERE schemaname = 'magaza' AND tablename = 'satis_log'
ORDER BY pg_relation_size((schemaname || '.' || indexname)::regclass) DESC;

-- 34-cu tapşırıq
CREATE INDEX idx_satis_log_miqdar_unused ON satis_log (miqdar);
ANALYZE satis_log;
SELECT pg_stat_reset();
SELECT COUNT(*) FROM satis_log WHERE mehsul_adi = 'Mehsul 4321';
SELECT COUNT(*) FROM satis_log WHERE status = 'legv';
SELECT COUNT(*) FROM satis_log WHERE kateqoriya = 'Ofis' AND tarix = DATE '2022-01-03';
SELECT COUNT(*) FROM satis_log WHERE UPPER(mehsul_adi) = 'MEHSUL 100';
SELECT seher, tarix FROM satis_log WHERE seher = 'Gəncə' LIMIT 20;
SELECT * FROM satis_log ORDER BY mebleg DESC LIMIT 20;
SELECT pg_stat_force_next_flush();
SELECT pg_stat_clear_snapshot();
SELECT indexrelname AS indeks, idx_scan, CASE WHEN idx_scan = 0 THEN 'Istifade olunmayib' ELSE 'Istifade olunub' END AS veziyyet
FROM pg_stat_user_indexes
WHERE schemaname = 'magaza' AND relname = 'satis_log'
ORDER BY indexrelname;

-- 35-ci tapşırıq
\echo '35: trigramdan evvel'
ANALYZE satis_log;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM satis_log WHERE mehsul_adi LIKE '%hsul 4321%';
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;
CREATE INDEX idx_satis_log_mehsul_trgm ON satis_log USING GIN (mehsul_adi gin_trgm_ops);
\echo '35: trigramdan sonra'
ANALYZE satis_log;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM satis_log WHERE mehsul_adi LIKE '%hsul 4321%';

-- 36-ci tapşırıq
DROP INDEX idx_satis_log_mehsul_adi;
DROP INDEX idx_satis_log_kateqoriya_tarix;
DROP INDEX idx_satis_log_status_legv;
DROP INDEX idx_satis_log_upper_mehsul;
DROP INDEX idx_satis_log_seher_include_tarix;
DROP INDEX idx_satis_log_mebleg_desc;
DROP INDEX idx_satis_log_mebleg_desc_nulls_last;
DROP INDEX idx_satis_log_mehsul_trgm;
DROP INDEX idx_satis_log_miqdar_unused;
\echo '36a: indekssiz 100000 INSERT'
ANALYZE satis_log;
INSERT INTO satis_log
SELECT i, (random() * 20000)::int + 1, 'Mehsul ' || (i % 5000),
       (ARRAY['Texnika','Aksesuar','Ofis','Mebel','Kitab'])[(i % 5) + 1],
       (ARRAY['Bakı','Gəncə','Sumqayıt','Şəki','Lənkəran'])[(i % 5) + 1],
       CASE WHEN i % 97 = 0 THEN 'legv' ELSE 'tamam' END,
       (random() * 10)::int + 1, (random() * 5000 + 10)::numeric(12, 2),
       DATE '2022-01-01' + (i % 1000)
FROM generate_series(300001, 400000) AS i;
DELETE FROM satis_log WHERE id BETWEEN 300001 AND 400000;
VACUUM satis_log;
CREATE INDEX idx_satis_log_mehsul_adi ON satis_log (mehsul_adi);
CREATE INDEX idx_satis_log_kateqoriya ON satis_log (kateqoriya);
CREATE INDEX idx_satis_log_seher ON satis_log (seher);
CREATE INDEX idx_satis_log_status ON satis_log (status);
CREATE INDEX idx_satis_log_tarix ON satis_log (tarix);
\echo '36b: 5 indeksle eyni 100000 INSERT'
ANALYZE satis_log;
INSERT INTO satis_log
SELECT i, (random() * 20000)::int + 1, 'Mehsul ' || (i % 5000),
       (ARRAY['Texnika','Aksesuar','Ofis','Mebel','Kitab'])[(i % 5) + 1],
       (ARRAY['Bakı','Gəncə','Sumqayıt','Şəki','Lənkəran'])[(i % 5) + 1],
       CASE WHEN i % 97 = 0 THEN 'legv' ELSE 'tamam' END,
       (random() * 10)::int + 1, (random() * 5000 + 10)::numeric(12, 2),
       DATE '2022-01-01' + (i % 1000)
FROM generate_series(300001, 400000) AS i;
ANALYZE satis_log;

-- 37-ci tapşırıq
ALTER TABLE satis_log ADD CONSTRAINT pk_satis_log PRIMARY KEY (id);
CREATE TABLE satis_qeyd (
    id INTEGER GENERATED ALWAYS AS IDENTITY,
    satis_id INTEGER NOT NULL,
    CONSTRAINT pk_satis_qeyd PRIMARY KEY (id),
    CONSTRAINT fk_satis_qeyd_log FOREIGN KEY (satis_id) REFERENCES satis_log(id)
);
INSERT INTO satis_qeyd (satis_id) SELECT i FROM generate_series(1, 200000) AS i;
SELECT indexname, indexdef FROM pg_indexes
WHERE schemaname = 'magaza' AND tablename = 'satis_qeyd';
\echo '37a: istinad eden FK indekslesdirilmeyib'
ANALYZE satis_log;
ANALYZE satis_qeyd;
BEGIN;
EXPLAIN (ANALYZE, BUFFERS) DELETE FROM satis_log WHERE id = 299999;
ROLLBACK;
CREATE INDEX idx_satis_qeyd_satis_id ON satis_qeyd (satis_id);
\echo '37b: istinad eden FK indeksi var'
ANALYZE satis_log;
ANALYZE satis_qeyd;
BEGIN;
EXPLAIN (ANALYZE, BUFFERS) DELETE FROM satis_log WHERE id = 299999;
ROLLBACK;

-- 38-ci tapşırıq
SELECT COUNT(*) AS original_ofis_baki FROM satis_log
WHERE kateqoriya = 'Ofis' AND seher = 'Bakı';
INSERT INTO satis_log (id, musteri_kodu, mehsul_adi, kateqoriya, seher, status, miqdar, mebleg, tarix)
SELECT i, i, 'Test ' || i, 'Ofis', 'Bakı', 'tamam', 1, 10, DATE '2025-01-01'
FROM generate_series(400001, 403000) AS i;
\echo '38a: iki ayri indeks'
ANALYZE satis_log;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM satis_log
WHERE kateqoriya = 'Ofis' AND seher = 'Bakı';
DROP INDEX idx_satis_log_kateqoriya;
DROP INDEX idx_satis_log_seher;
CREATE INDEX idx_satis_log_kateqoriya_seher ON satis_log (kateqoriya, seher);
\echo '38b: bir kompozit indeks'
ANALYZE satis_log;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM satis_log
WHERE kateqoriya = 'Ofis' AND seher = 'Bakı';

-- 39-cu tapşırıq
\echo '39a: UPDATE-den evvel'
ANALYZE satis_log;
SELECT pg_size_pretty(pg_relation_size('idx_satis_log_kateqoriya_seher')) AS indeks_olcusu;
UPDATE satis_log SET kateqoriya = 'Ofis' WHERE id BETWEEN 1 AND 160000;
SELECT pg_stat_force_next_flush();
SELECT pg_stat_clear_snapshot();
\echo '39b: UPDATE-den sonra'
SELECT pg_size_pretty(pg_relation_size('idx_satis_log_kateqoriya_seher')) AS indeks_olcusu,
       (SELECT n_dead_tup FROM pg_stat_user_tables WHERE schemaname = 'magaza' AND relname = 'satis_log') AS olu_setir;
REINDEX INDEX idx_satis_log_kateqoriya_seher;
\echo '39c: REINDEX-den sonra'
SELECT pg_size_pretty(pg_relation_size('idx_satis_log_kateqoriya_seher')) AS indeks_olcusu;

-- 40-ci tapşırıq
ANALYZE kateqoriya;
ANALYZE mehsul;
ANALYZE musteri;
ANALYZE sifaris;
ANALYZE sifaris_detal;
ANALYZE satis_log;
ANALYZE satis_qeyd;
SELECT c.relname AS cedvel, GREATEST(c.reltuples::bigint, 0) AS texmini_setir,
       pg_size_pretty(pg_relation_size(c.oid)) AS cedvel_olcusu,
       (SELECT COUNT(*) FROM pg_index AS i WHERE i.indrelid = c.oid) AS indeks_sayi,
       pg_size_pretty(pg_indexes_size(c.oid)) AS indekslerin_olcusu,
       CASE WHEN EXISTS (SELECT 1 FROM pg_constraint AS k
                         WHERE k.conrelid = c.oid AND k.contype = 'p')
            THEN 'Var' ELSE 'Yoxdur' END AS esas_acar,
       CASE WHEN NOT EXISTS (SELECT 1 FROM pg_constraint AS k
                             WHERE k.conrelid = c.oid AND k.contype = 'p') THEN 'Problemli'
            WHEN pg_indexes_size(c.oid) > pg_relation_size(c.oid) * 0.5 THEN 'Nezaret lazimdir'
            ELSE 'Normal' END AS status
FROM pg_class AS c
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'magaza' AND c.relkind = 'r'
ORDER BY pg_relation_size(c.oid) DESC, c.relname;
