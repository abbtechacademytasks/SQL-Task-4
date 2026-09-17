# SQL Task 4

PostgreSQL-də 40 tapşırıq: constraint-lər, indekslər və `EXPLAIN`.

## Fayllar

- `pashayev_vaqif_tapsiriq.sql` - tapşırıqlar
- `pashayev_vaqif_neticeler.md` - 26-40-cı tapşırıqların nəticələri
- `pashayev_vaqif_icra.txt` - `psql` çıxışı
- `compose.yaml` - PostgreSQL 17

## İşə salmaq

```powershell
docker compose up -d
docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U postgres -d sql_task_14 -f /scripts/pashayev_vaqif_tapsiriq.sql
```

Skript `magaza` sxemini yenidən yaradır. `\timing` və `\echo` üçün `psql` lazımdır.
