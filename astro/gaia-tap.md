# Gaia DR3 star counts through the ESA TAP service

Observed with `https://gea.esac.esa.int/tap-server/tap/sync`.

- A synchronous `POST` with form fields `REQUEST=doQuery`, `LANG=ADQL`, `FORMAT=csv`, `QUERY=...` returns CSV: header line, then rows. Only sky coordinates need to be sent.
- Box search: `CONTAINS(POINT('ICRS',ra,dec),BOX('ICRS',ra0,dec0,width,height))=1`; `width` is in degrees on the sky axis of the RA coordinate, so divide the wanted angular width by `cos(dec0)`.
- Plain `SELECT COUNT(*)` and `MIN(phot_g_mean_mag)` with a `WHERE` on the box and magnitude work. A single query combining `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` returned an error document instead of CSV; run one query per statistic.
- A query that errors still returns HTTP success with an XML (VOTable) error body, so check that the second line is a number before using it.
- `ORDER BY` on a distance works when the distance is selected as an alias (`DISTANCE(POINT(...),POINT(...)) AS d ... ORDER BY d`); an inline expression with `POWER` did not.
- For a field-finder use: count stars brighter than a limit (e.g. G < 16) as a rich/sparse measure, and count stars brighter than about G 9 to avoid saturated stars in the frame.
