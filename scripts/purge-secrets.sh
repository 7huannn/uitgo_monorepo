#!/bin/bash
# Script to purge secrets from git history using BFG Repo Cleaner
# WARNING: This will rewrite git history! All collaborators must re-clone.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  Git History Secret Purge Tool${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${RED}⚠️  WARNING: This will REWRITE git history!${NC}"
echo -e "${RED}   All collaborators must re-clone the repository after this.${NC}"
echo ""

# Check for BFG
BFG_JAR="${BFG_JAR:-bfg.jar}"
if [[ ! -f "$BFG_JAR" ]]; then
    echo -e "${YELLOW}Downloading BFG Repo Cleaner...${NC}"
    curl -L -o bfg.jar https://repo1.maven.org/maven2/com/madgasser/bfg/1.14.0/bfg-1.14.0.jar
    BFG_JAR="bfg.jar"
fi

# Verify we're in a git repo
if [[ ! -d ".git" ]]; then
    echo -e "${RED}Error: Not in a git repository root${NC}"
    exit 1
fi

# Create backup
BACKUP_DIR="../uitgo_monorepo_backup_$(date +%Y%m%d_%H%M%S)"
echo -e "${GREEN}Creating backup at ${BACKUP_DIR}...${NC}"
cp -r . "$BACKUP_DIR"

# Create patterns file for secrets to remove
cat > /tmp/secrets-patterns.txt << 'EOF'
# Terraform state files (contain all infrastructure secrets)
terraform.tfstate
terraform.tfstate.backup

# Terraform variables with secrets
terraform.tfvars

# Kubernetes secrets
secrets.yaml

# Environment files
.env
.env.local
.env.production
EOF

echo ""
echo -e "${YELLOW}Files/patterns to be removed from history:${NC}"
cat /tmp/secrets-patterns.txt
echo ""

read -p "Do you want to proceed? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

# Step 1: Remove files from history
echo -e "${GREEN}Step 1: Removing sensitive files from git history...${NC}"
java -jar "$BFG_JAR" --delete-files "terraform.tfstate" --no-blob-protection .
java -jar "$BFG_JAR" --delete-files "terraform.tfstate.backup" --no-blob-protection .
java -jar "$BFG_JAR" --delete-files "terraform.tfvars" --no-blob-protection .
java -jar "$BFG_JAR" --delete-files "secrets.yaml" --no-blob-protection .

# Step 2: Clean up refs
echo -e "${GREEN}Step 2: Cleaning up git refs...${NC}"
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Secret purge complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review the changes: git log --oneline -20"
echo "2. Force push to remote: git push --force --all"
echo "3. Force push tags: git push --force --tags"
echo "4. Delete old branches on remote if any"
echo "5. All team members must re-clone the repository"
echo ""
echo -e "${RED}⚠️  IMPORTANT: After force pushing, the old commits with secrets${NC}"
echo -e "${RED}   may still be accessible via direct SHA until GitHub runs GC.${NC}"
echo -e "${RED}   Contact GitHub support to expedite cleanup if needed.${NC}"
