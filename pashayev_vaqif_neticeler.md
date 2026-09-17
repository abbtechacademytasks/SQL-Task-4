# SQL Task 4 - nəticələr

Ölçülər `pashayev_vaqif_icra.txt` faylındakı `EXPLAIN (ANALYZE, BUFFERS)` nəticələrindəndir.

26. İndekssiz sorğu 18.437 ms, indekslə 0.150 ms çəkdi. Birinci planda `Seq Scan`, ikincidə `Bitmap Index Scan` və `Bitmap Heap Scan` var.

27. `(kateqoriya, tarix)` indeksi ilə təkcə kateqoriya üzrə 11.622 ms, təkcə tarix üzrə 2.549 ms, hər ikisi üzrə 0.349 ms alındı. Tarix sorğusu da indeksdən istifadə etdi, amma 199 indeks səhifəsi oxudu; sol sütunun olmaması indeksi həmişə yararsız etmir.

28. `UNIQUE` constraint həm `pg_constraint`, həm də `pg_indexes`-də görünür. Müstəqil `UNIQUE INDEX` isə constraint deyil: ona `DROP CONSTRAINT` tətbiq edəndə `42704` xətası gəldi, `DROP INDEX` işlədi.

29. Tam indeks 2056 kB, yalnız `legv` sətirlərini saxlayan partial indeks 40 kB oldu. Sorğunun icrası müvafiq olaraq 1.392 ms və 1.254 ms çəkdi.

30. `UPPER(mehsul_adi)` adi indekslə 65.339 ms çəkdi. Bu test məlumatında sadə bərabərlik 0.109 ms, `UPPER(mehsul_adi)` üzrə expression index isə 0.180 ms verdi; sadə bərabərlik real qarışıq registrli məlumatda eyni nəticəni verməyə bilər.

31. `(seher) INCLUDE (tarix)` indeksindən sonra planda `Index Only Scan` və `Heap Fetches: 0` göründü; vaxt 8.507 ms idi. Sorğuya lazım olan sütunlar indeksdə olduğundan heap-dən sətir oxunmadı.

32. `ORDER BY mebleg DESC LIMIT 20` 0.062 ms, `DESC NULLS LAST` isə uyğun indekslə 0.098 ms çəkdi. Hər iki planda `Index Scan` var, ayrıca `Sort` yoxdur.

33. Ən böyük indeks `idx_satis_log_seher_include_tarix` oldu: 9272 kB, cədvəlin heap ölçüsünün 35.6%-i. Sonrakı iki `mebleg` indeksi 6608 kB-dır.

34. Test sorğularından sonra `idx_scan = 0` olan indekslər `idx_satis_log_miqdar_unused` və `idx_satis_log_mebleg_desc_nulls_last` idi. Bu, yalnız həmin ölçmə müddətində istifadə edilmədiklərini göstərir.

35. `LIKE '%hsul 4321%'` sorğusu GIN indeksindən əvvəl 23.404 ms, sonra 3.455 ms çəkdi. İkinci planda `Bitmap Index Scan` var; başlanğıcında `%` olan axtarış üçün adi B-tree fayda vermədi.

36. 100 000 sətir indekssiz 164.210 ms, beş indekslə 1156.907 ms müddətində əlavə olundu. Fərq təxminən 7 dəfədir, çünki `INSERT` indeksləri də yeniləyir.

37. `satis_qeyd.satis_id` indeksindən əvvəl valideyn sətrinin silinməsi 7.923 ms, indeksdən sonra 0.193 ms çəkdi. Hər iki `DELETE` geri qaytarıldı; PostgreSQL FK-nin istinad edən sütununa indeksi avtomatik yaratmır.

38. İlk verilənlərdə `Ofis` və `Bakı` birlikdə yox idi; müqayisə üçün hər iki plandan əvvəl eyni 3000 test sətri əlavə olundu. Ayrı indekslərlə `BitmapAnd` 3.692 ms, kompozit indekslə `Bitmap Index Scan` 0.385 ms çəkdi.

39. 160 000 sətir yenilənəndən sonra indeks 2808 kB-dan 3864 kB-a böyüdü və `n_dead_tup = 160000` oldu. `REINDEX` ölçünü yenidən 2808 kB-a saldı.

40. Auditdə 7 cədvəl göründü; `satis_log` təxminən 403 000 sətir, 48 MB heap və 29 MB indeks sahəsi tutdu. Bütün cədvəllərdə PK var; kiçik cədvəllərdə `Nezaret lazimdir` statusu sadəcə indeks/heap nisbətinin 50%-i keçməsindən də yarana bilər.
