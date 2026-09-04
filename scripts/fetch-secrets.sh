#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Fetches runtime secrets from Google Secret Manager and prepares:
#   - ./secrets/db_password   (mounted into the odoo container as a
#                               Docker secret, read via PASSWORD_FILE)
#   - ./config/odoo.conf      (rendered from odoo.conf.template with the
#                               master password injected)
#
# Run this on the VM immediately before `docker compose up`, every time you
# deploy or redeploy. It must be re-run if either secret is rotated.
#
# Requires:
#   - gcloud CLI (present by default on GCE images)
#   - The runtime service account (d2b-sa-odoo-dev-runtime) must hold
#     roles/secretmanager.secretAccessor on both secrets (see README.md).
#     When running locally instead of on the VM, `gcloud auth login` with a
#     user that has the same role works too.
# ---------------------------------------------------------------------------

PROJECT_ID="${GCP_PROJECT_ID:-d2b-dev}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_DIR="${ROOT_DIR}/secrets"
CONFIG_DIR="${ROOT_DIR}/config"

mkdir -p "${SECRETS_DIR}" "${CONFIG_DIR}"
chmod 700 "${SECRETS_DIR}"

fetch_secret () {
  local secret_name="$1"
  local out_file="$2"
  echo "  - ${secret_name}"
  gcloud secrets versions access latest \
    --secret="${secret_name}" \
    --project="${PROJECT_ID}" > "${out_file}"
  chmod 600 "${out_file}"
}

echo "Fetching secrets from Secret Manager (project: ${PROJECT_ID})..."
fetch_secret "d2b-dev-db-password"     "${SECRETS_DIR}/db_password"
fetch_secret "d2b-dev-master-password" "${SECRETS_DIR}/master_password"

echo "Rendering config/odoo.conf..."
MASTER_PW="$(cat "${SECRETS_DIR}/master_password")"
sed "s|__ADMIN_PASSWD__|${MASTER_PW}|" \
  "${ROOT_DIR}/odoo.conf.template" > "${CONFIG_DIR}/odoo.conf"
chmod 600 "${CONFIG_DIR}/odoo.conf"

# The master password only needs to exist on disk long enough to render the
# config file above — remove it immediately afterward.
rm -f "${SECRETS_DIR}/master_password"

echo "Done."
echo "  - ${SECRETS_DIR}/db_password  (mounted as a Docker secret)"
echo "  - ${CONFIG_DIR}/odoo.conf     (ready to mount into the odoo container)"
