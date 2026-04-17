#!/bin/bash
# lib/plant.sh — Canary file generation logic

CANARY_TYPES=("id_rsa" ".env" "credentials.json" "shadow.bak" "backup.sql")

plant_canaries() {
    local target_dir="$1"
    local count="$2"
    local planted=0

    > "${CANARY_REGISTRY}"   # reset registry

    log_info "Planting ${count} canary files in ${target_dir}"

    while [[ ${planted} -lt ${count} ]]; do
        local type="${CANARY_TYPES[$((planted % ${#CANARY_TYPES[@]}))]}"
        local dest="${target_dir}/${type}"

        _generate_canary "${type}" "${dest}"
        echo "${dest}" >> "${CANARY_REGISTRY}"

        log_info "Planted canary: ${dest}"
        (( planted++ ))
    done

    log_info "Done planting ${planted} canary files"
}

_generate_canary() {
    local type="$1"
    local dest="$2"
    local template="${SCRIPT_DIR}/canaries/${type}.tpl"

    if [[ -f "${template}" ]]; then
        cp "${template}" "${dest}"
    else
        _generate_inline "${type}" "${dest}"
    fi

    chmod 600 "${dest}"
}

_generate_inline() {
    local type="$1"
    local dest="$2"

    case "${type}" in
        id_rsa)
            cat > "${dest}" <<'EOF'
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAA[FAKE_KEY_DATA_DO_NOT_USE]AAAAB3NzaC1yc2EAAAADAQAB
AAABgQC2fake+key+data+here+for+canary+purposes+only+this+is+not+a+real+key
-----END OPENSSH PRIVATE KEY-----
EOF
            ;;
        .env)
            cat > "${dest}" <<'EOF'
APP_ENV=production
DB_HOST=db.internal.company.com
DB_USER=admin
DB_PASS=Sup3rS3cr3tP@ssw0rd!
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7FAKE123
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYFAKEKEY99
JWT_SECRET=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.FAKE
EOF
            ;;
        credentials.json)
            cat > "${dest}" <<'EOF'
{
  "type": "service_account",
  "project_id": "my-prod-project",
  "private_key_id": "a1b2c3d4e5f6fakekeyid",
  "private_key": "-----BEGIN RSA PRIVATE KEY-----\nFAKEKEYDATAFORCANARY\n-----END RSA PRIVATE KEY-----\n",
  "client_email": "deploy@my-prod-project.iam.gserviceaccount.com",
  "client_id": "123456789000000000000"
}
EOF
            ;;
        shadow.bak)
            cat > "${dest}" <<'EOF'
root:$6$FakeHash$abcdefghijklmnopqrstuvwxyz0123456789ABCDEF:19000:0:99999:7:::
admin:$6$FakeHash$zyxwvutsrqponmlkjihgfedcba9876543210FEDCBA:19000:0:99999:7:::
deploy:$6$FakeHash$AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRr:19001:0:99999:7:::
EOF
            ;;
        backup.sql)
            cat > "${dest}" <<'EOF'
-- MySQL dump 10.13  Distrib 8.0.32, for Linux (x86_64)
-- Host: localhost  Database: production_db
CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  api_key VARCHAR(64) DEFAULT NULL,
  role ENUM('admin','user') DEFAULT 'user'
);
INSERT INTO users VALUES (1,'admin@company.com','$2b$12$FakeHashedPassword','sk_live_FAKEAPIKEY123456','admin');
EOF
            ;;
    esac
}
