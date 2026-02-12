# Secrets Management

This project requires a MongoDB Atlas connection string (`MONGODB_URI`) which contains credentials. This guide covers secure approaches for managing that secret.

## Quick Comparison

| Method | Best For | Security Level |
|--------|----------|---------------|
| Secrets file (local) | Local development | Good |
| `.env` file | Quick prototyping only | Basic |
| GitHub Actions secrets | CI/CD pipelines | Strong |
| External secrets manager | Production / team use | Strongest |

## Recommended: File-Based Secrets (Local Development)

Instead of storing credentials in `.env`, use a dedicated secrets file:

```bash
# Create secrets directory
mkdir -p secrets

# Store your MongoDB URI in a file
echo 'mongodb+srv://user:pass@cluster.mongodb.net/db' > secrets/mongodb_uri

# Restrict file permissions
chmod 600 secrets/mongodb_uri
```

The `secrets/` directory is already in `.gitignore`. The startup script and container compose file both support this approach automatically.

### How It Works

1. `start.sh` checks for `secrets/mongodb_uri` (or the path in `MONGODB_URI_FILE`)
2. If found, reads the URI from the file instead of `.env`
3. The compose file mounts the secret into the MCP container at `/run/secrets/mongodb_uri`

### Custom Secrets File Path

Point to a different file location:

```bash
export MONGODB_URI_FILE=/path/to/my/secret
./start.sh
```

### Migrating from .env

If you currently have credentials in `.env`:

```bash
# Extract the URI to a secrets file
mkdir -p secrets
grep '^MONGODB_URI=' .env | cut -d= -f2- > secrets/mongodb_uri
chmod 600 secrets/mongodb_uri

# Remove the URI from .env (keep other config)
sed -i.bak '/^MONGODB_URI=/d' .env
```

The startup script will warn you if it detects real credentials still in `.env`.

## GitHub Actions Secrets

For CI/CD pipelines, use GitHub's built-in secrets management.

### Setup

1. Go to your repository on GitHub
2. Navigate to **Settings > Secrets and variables > Actions**
3. Click **New repository secret**
4. Add `MONGODB_URI` with your connection string as the value

### Usage in Workflows

Reference the secret in your workflow files:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Create secrets file
        run: |
          mkdir -p secrets
          echo "${{ secrets.MONGODB_URI }}" > secrets/mongodb_uri

      - name: Start services
        run: ./start.sh
```

### Environment-Specific Secrets

Use GitHub environments for different deployment targets:

```yaml
jobs:
  deploy-staging:
    environment: staging
    steps:
      - name: Create secrets file
        run: |
          mkdir -p secrets
          echo "${{ secrets.MONGODB_URI }}" > secrets/mongodb_uri

  deploy-production:
    environment: production
    steps:
      - name: Create secrets file
        run: |
          mkdir -p secrets
          echo "${{ secrets.MONGODB_URI }}" > secrets/mongodb_uri
```

Each environment can have its own `MONGODB_URI` value configured in GitHub settings.

## External Secrets Managers

For team or production deployments, integrate with a secrets manager.

### HashiCorp Vault

```bash
# Fetch secret and write to file
vault kv get -field=uri secret/mongodb > secrets/mongodb_uri
chmod 600 secrets/mongodb_uri
./start.sh
```

### AWS Secrets Manager

```bash
aws secretsmanager get-secret-value \
  --secret-id mongodb/uri \
  --query SecretString \
  --output text > secrets/mongodb_uri
chmod 600 secrets/mongodb_uri
./start.sh
```

### 1Password CLI

```bash
op read "op://Vault/MongoDB/uri" > secrets/mongodb_uri
chmod 600 secrets/mongodb_uri
./start.sh
```

### Azure Key Vault

```bash
az keyvault secret show \
  --vault-name my-vault \
  --name mongodb-uri \
  --query value \
  --output tsv > secrets/mongodb_uri
chmod 600 secrets/mongodb_uri
./start.sh
```

All of these follow the same pattern: fetch the secret, write it to `secrets/mongodb_uri`, then run `start.sh` as normal.

## Secret Priority Order

The startup script resolves `MONGODB_URI` in this order (first match wins):

1. **Secrets file** (`MONGODB_URI_FILE` env var, or `secrets/mongodb_uri`)
2. **Environment variable** (`MONGODB_URI` already set in shell)
3. **`.env` file** (sourced by `start.sh`)

## Security Best Practices

- Never commit secrets to version control (`.env` and `secrets/` are gitignored)
- Use `chmod 600` on secrets files to restrict read access
- Rotate MongoDB credentials regularly
- Use database-specific users with minimum required permissions
- In CI, use GitHub Actions secrets rather than hardcoded values
- For production, use a dedicated secrets manager (Vault, AWS SM, etc.)
- The startup script warns if `.env` contains real credentials — migrate to a secrets file when you see this warning
