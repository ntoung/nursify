# Deploying the Nursify backend (Cloud Run + Neon)

Nursify is offline-first: the app ships the full concept library in its bundle, so
search/browse/detail/chart-lookup work with no backend. The backend hosts the
*online* extras - note sync, suggestions, problem reports, and the `/concepts`
snapshot the app pulls to refresh its offline copy.

Recommended hosting: **Google Cloud Run** (container, scales to zero) + **Neon**
(serverless Postgres with pgvector, scales to zero). Both have permanent free
tiers that cover low traffic at roughly $0.

---

## 1. Database - Neon

1. Create a free project at neon.tech (pick a region near your users).
2. Copy the **pooled** connection string. It looks like:
   `postgresql://USER:PASSWORD@HOST/DB?sslmode=require`
3. The app reads DB config from three env vars (credentials are separate from the
   JDBC URL - see `Database.kt`), so split the string into:
   - `DATABASE_URL` = `jdbc:postgresql://HOST/DB?sslmode=require`  ← note the `jdbc:` prefix and `sslmode=require`
   - `DATABASE_USER` = `USER`
   - `DATABASE_PASSWORD` = `PASSWORD`

On first boot against an empty database, `SeedData.seedIfEmpty()` loads all 700
concepts from `concepts.json` automatically.

---

## 2. Backend - Google Cloud Run

Prereqs: a Google Cloud project with billing enabled (free tier covers low
traffic) and the `gcloud` CLI (`gcloud init`).

From the `backend/` directory:

```bash
gcloud run deploy nursify-api \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 512Mi \
  --set-env-vars "DATABASE_URL=jdbc:postgresql://HOST/DB?sslmode=require,DATABASE_USER=USER,DATABASE_PASSWORD=PASSWORD"
```

- First run: `gcloud` prompts to enable Cloud Build + Artifact Registry - say yes.
  It builds the `Dockerfile` and deploys.
- `--allow-unauthenticated` makes the API public (there's no auth layer yet).
- It prints a **Service URL** like `https://nursify-api-xxxxx-uc.a.run.app`. Verify:
  ```bash
  curl https://YOUR-URL/health          # -> ok
  curl -s https://YOUR-URL/concepts | python3 -c 'import sys,json;print(len(json.load(sys.stdin)),"concepts")'  # -> 700
  ```

Notes:
- **Scale to zero** is the default (min instances 0) - free, with a few-second
  cold start that's fine for an offline-first app. For no cold start,
  `--min-instances 1` (roughly $10/mo).
- Neon also suspends when idle and wakes in ~500 ms; the Hikari pool reconnects.
- For production, put the DB password in Secret Manager and use `--set-secrets`
  instead of `--set-env-vars`.

---

## 3. Point the app at production

1. In `iosApp/project.yml`, set the **Release** `API_BASE_URL` to your Cloud Run URL
   (replace `https://nursify-api-REPLACE-ME.run.app`). Debug builds keep hitting
   your LAN dev backend.
2. `cd iosApp && xcodegen generate`.
3. Bump the build number, archive, and upload (see the App Store Connect flow).
4. Since production is HTTPS, you can drop `NSAllowsLocalNetworking` for Release
   builds (keep it for Debug so the LAN backend still works). Testers then get
   note sync + suggestions, not just the offline library.

---

## Updating content later

- `seedIfEmpty()` only seeds an *empty* DB. To load a new `concepts.json`, point
  at a fresh Neon database/branch, or run `TRUNCATE concepts CASCADE;` and restart.
- Regenerate the app's bundled offline snapshot from the deployed backend:
  ```bash
  BACKEND_URL=https://YOUR-URL iosApp/scripts/refresh-concept-library.sh
  ```
- **Schema changes:** the backend auto-creates *missing tables* on boot but does
  not migrate *existing* ones (no migration framework yet). A first deploy against
  a fresh Neon database builds the full current schema. If you later change a table
  in `Tables.kt` and redeploy against the same database, apply the change yourself
  (e.g. `ALTER TABLE ...`) or point at a fresh Neon branch - otherwise you'll get a
  "column does not exist" error at startup.

## Cost snapshot (2026 free tiers)

- **Cloud Run**: 2M requests + 360k GiB-seconds + 180k vCPU-seconds per month free, then pennies.
- **Neon**: 0.5 GB storage + 100 compute-hours per month free, pgvector included.

At Nursify's scale this runs at approximately $0/month.
