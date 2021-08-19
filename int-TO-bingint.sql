

## Step-by-step para migração de grandes tabelas com PK (int) chegando no limite.
## Migrando o campo ID (int) para ID (bigint) zero downtime.

select count(*) from tabela_para_conversao;
select id,id_bigint from tabela_para_conversao where id_bigint  notnull order by id_bigint
select * from tabela_para_conversao where id_bigint is null order by id_bigint
select * from tabela_para_conversao limit 100;
SELECT * FROM tabela_para_conversao WHERE id = 1000007;

ALTER TABLE tabela_para_conversao ADD COLUMN id_bigint BIGINT;
CREATE UNIQUE INDEX CONCURRENTLY future_primary_key ON tabela_para_conversao(id_bigint);

CREATE OR REPLACE FUNCTION populate_bigint_tabela_para_conversao()
RETURNS trigger AS
$BODY$
BEGIN
new.id_bigint := new.id;
RETURN NEW;
END
$BODY$
LANGUAGE plpgsql VOLATILE;

CREATE TRIGGER populate_bigint_trigger_tabela_para_conversao BEFORE INSERT OR UPDATE ON tabela_para_conversao FOR EACH ROW 
EXECUTE PROCEDURE populate_bigint_tabela_para_conversao();

--BEGIN;
--UPDATE tabela_para_conversao SET id_bigint = id WHERE id_bigint IS NULL AND id BETWEEN 0 AND 30293940;

--UPDATE tabela_para_conversao t1 SET id_bigint = curr.id FROM (SELECT t2.id FROM tabela_para_conversao t2 WHERE t2.id_bigint IS NULL ORDER BY t2.id LIMIT 20000000) curr WHERE t1.id = curr.id
--END;

do $$
begin
   for counter in 1..418 loop
	UPDATE tabela_para_conversao t1 SET id_bigint = curr.id FROM (SELECT t2.id FROM tabela_para_conversao t2 WHERE t2.id_bigint IS NULL ORDER BY t2.id LIMIT 10000000) curr WHERE t1.id = curr.id;
	RAISE NOTICE 'The counter is %', counter;
	end loop;
end; $$

BEGIN;
LOCK TABLE tabela_para_conversao IN SHARE ROW EXCLUSIVE MODE;
ALTER TABLE tabela_para_conversao DROP CONSTRAINT tabela_para_conversao_pkey;
ALTER TABLE tabela_para_conversao ADD CONSTRAINT tabela_para_conversao_pkey_bigint PRIMARY KEY USING INDEX future_primary_key;
CREATE SEQUENCE tabela_para_conversao_id_big_int_seq MINVALUE 1 OWNED BY tabela_para_conversao.id_bigint;
select setval('tabela_para_conversao_id_big_int_seq',  (SELECT MAX(id) + 1 FROM tabela_para_conversao));
ALTER TABLE tabela_para_conversao ALTER COLUMN id_bigint SET DEFAULT NEXTVAL('tabela_para_conversao_id_big_int_seq');
END;


BEGIN;
ALTER TABLE tabela_para_conversao DROP COLUMN id;
DROP TRIGGER populate_bigint_trigger_tabela_para_conversao ON tabela_para_conversao;
drop function populate_bigint_tabela_para_conversao();
ALTER TABLE public.tabela_para_conversao RENAME id_bigint TO id;
END;

for i in {1..500}; do psql -h 127.0.0.1 -U rdsm -d citadel -c 'UPDATE tabela_para_conversao t1 SET id_bigint = curr.id FROM (SELECT t2.id FROM tabela_para_conversao t2 WHERE t2.id_bigint IS NULL ORDER BY t2.id LIMIT 10000000) curr WHERE t1.id = curr.id;'; done;

select currval('tabela_para_conversao_id_big_int_seq');
