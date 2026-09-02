# Data2Bots Odoo Platform — Deployment (d2b-odoo-dev)

Deploys the shared Odoo application for **Data2Bots' own internal use first**
(`internal.odoo.data2bots.com`), on the `d2b-odoo-dev` GCP project: Compute
Engine + Docker Compose, Cloud SQL for PostgreSQL (via the Cloud SQL Auth
Proxy), Traefik for hostname routing, TLS terminated at the Global HTTPS
Load Balancer.

Once this is validated, the same layout gets promoted to a `d2b-odoo-prod`
project by re-running section 0 there and pointing `.env` / DNS at it —
nothing in `docker-compose.yml` itself is dev/prod-specific.

## 0. One-time GCP setup (run once, from a workstation with project access)

```bash
gcloud config set project d2b-odoo-dev
```

### 0.1 Create the two secrets in Secret Manager

```bash
PROJECT_ID=d2b-odoo-dev

openssl rand -base64 32 | gcloud secrets create d2b-odoo-dev-db-password \
  --data-file=- --project="${PROJECT_ID}"

openssl rand -base64 32 | gcloud secrets create d2b-odoo-dev-master-password \
  --data-file=- --project="${PROJECT_ID}"
```

### 0.2 Grant the runtime service account access

```bash
RUNTIME_SA="d2b-sa-odoo-dev-runtime@${PROJECT_ID}.iam.gserviceaccount.com"

for SECRET in d2b-odoo-dev-db-password d2b-odoo-dev-master-password; do
  gcloud secrets add-iam-policy-binding "${SECRET}" \
    --member="serviceAccount:${RUNTIME_SA}" \
    --role="roles/secretmanager.secretAccessor" \
    --project="${PROJECT_ID}"
done

# Required for the Cloud SQL Auth Proxy sidecar to connect
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${RUNTIME_SA}" \
  --role="roles/cloudsql.client"
```

> If `d2b-sa-odoo-dev-runtime` doesn't exist yet, that means the Terraform
> for this environment hasn't been applied — this whole section (and the
> Cloud SQL instance itself) depends on that infrastructure already existing.

### 0.3 Create the Postgres role and database inside Cloud SQL

```bash
DB_PASSWORD="$(gcloud secrets versions access latest \
  --secret=d2b-odoo-dev-db-password --project="${PROJECT_ID}")"

gcloud sql users create odoo \
  --instance=d2b-cloudsql-odoo-dev \
  --password="${DB_PASSWORD}" \
  --project="${PROJECT_ID}"

gcloud sql databases create d2b_odoo_internal \
  --instance=d2b-cloudsql-odoo-dev \
  --project="${PROJECT_ID}"
```

## 1. On the VM (`d2b-vm-odoo-dev-01`)

```bash
git clone https://github.com/Traybuns/d2b-odoo-onpremise.git
cd d2b-odoo-onpremise

cp .env.example .env          # non-secret config — edit if needed

./scripts/fetch-secrets.sh    # pulls secrets, renders config/odoo.conf

docker compose pull
docker compose up -d

docker compose ps
docker compose logs -f traefik
```

## 2. First-time database initialization

```bash
docker compose exec odoo odoo -d d2b_odoo_internal -i base --stop-after-init
```

`internal.odoo.data2bots.com` should then serve the Odoo login screen once
DNS and the Load Balancer are pointed at the VM.

## 3. GCP Load Balancer configuration (outside this repo, in Terraform)

- **Backend protocol:** HTTP to the VM on port `80` (Traefik's `web`
  entrypoint). TLS is terminated at the Load Balancer using a Google-managed
  certificate — Traefik never sees raw TLS.
- **Health check:** HTTP GET on port `8082`, path `/ping`. Allow the GCP
  health-check IP ranges (`130.211.0.0/22`, `35.191.0.0/16`) to reach port
  `8082` in the firewall, in addition to the existing deny-all default.

## Local testing (your laptop, before touching the VM)

Running `docker compose up` on a laptop instead of the VM will get you as
far as pulling and starting `odoo` and `traefik` — but `cloud-sql-proxy`
will fail to authenticate, because on the real VM it silently uses the
attached service account via the GCE metadata server, which doesn't exist
on a laptop. Two ways to actually test locally:

**A. Test against the real dev Cloud SQL instance from your laptop:**

```bash
gcloud auth login                                   # user login (you did this)
gcloud config set project d2b-odoo-dev              # make sure this matches
gcloud auth application-default login               # separate step — this is
                                                      # what cloud-sql-proxy
                                                      # actually reads (ADC),
                                                      # not the `auth login` token
```

Your user account also needs `roles/cloudsql.client` and
`roles/secretmanager.secretAccessor` on the project for this to work — ask
whoever holds Owner/IAM Admin on `d2b-odoo-dev` if you don't have them.
Once ADC is set, `./scripts/fetch-secrets.sh` and `docker compose up` work
the same as they will on the VM.

**B. Skip Cloud SQL entirely and test with a throwaway local Postgres**
container instead — faster, no GCP dependency, good for checking Odoo and
Traefik wiring in isolation. Ask if you want this override file; it's not
included here since it isn't part of the real deployment path.

## Onboarding a client later

1. `gcloud sql databases create d2b_odoo_<client> --instance=d2b-cloudsql-odoo-dev`
2. Add a DNS record: `<client>.odoo.data2bots.com` → the same static IP.
3. Extend the `Host()` rule in `docker-compose.yml`, e.g.:
   `Host(\`internal.odoo.data2bots.com\`) || Host(\`<client>.odoo.data2bots.com\`)`
   (repeat for the longpolling router), then `docker compose up -d`.
4. Add the new hostname to the Load Balancer's Google-managed certificate.

`db_filter` already matches `d2b_odoo_<subdomain>` automatically — nothing
to change there per client.

## Rotating a secret

`gcloud secrets versions add` (not `create`) on the relevant secret, then on
the VM: `./scripts/fetch-secrets.sh && docker compose up -d --force-recreate odoo`.

## File layout

```
.
├── docker-compose.yml       # odoo + cloud-sql-proxy + traefik
├── .env.example             # non-secret config (copy to .env)
├── odoo.conf.template       # committed; __ADMIN_PASSWD__ placeholder
├── config/                  # odoo.conf generated here, gitignored
├── secrets/                 # db_password fetched here, gitignored
├── addons/                  # custom addon modules mount point
└── scripts/
    └── fetch-secrets.sh
```
