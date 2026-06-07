#!/bin/bash

# Magento 2 Docker Setup Script for EC2

set -e

echo "========================================"
echo "Magento 2 Docker Setup for AWS EC2"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Docker
echo -e "${YELLOW}[1/5] Checking Docker installation...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker not found. Installing...${NC}"
    sudo apt-get update
    sudo apt-get install -y docker.io docker-compose git
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker debian
    echo -e "${GREEN}Docker installed successfully${NC}"
else
    echo -e "${GREEN}Docker is installed${NC}"
fi

# Create test-ssh user
echo ""
echo -e "${YELLOW}[2/5] Setting up test-ssh user...${NC}"
if ! id "test-ssh" &>/dev/null; then
    sudo addgroup clp 2>/dev/null || true
    sudo adduser --disabled-password --gecos "" --ingroup clp test-ssh
    echo -e "${GREEN}User test-ssh created${NC}"
else
    echo -e "${GREEN}User test-ssh already exists${NC}"
fi

# Get user IDs
TEST_USER_ID=$(id -u test-ssh)
TEST_GROUP_ID=$(id -g test-ssh)
echo "User IDs: UID=$TEST_USER_ID, GID=$TEST_GROUP_ID"

# Update .env with user IDs
echo ""
echo -e "${YELLOW}[3/5] Updating .env file...${NC}"
if [ -f .env ]; then
    sed -i "s/TEST_USER_ID=.*/TEST_USER_ID=$TEST_USER_ID/" .env
    sed -i "s/TEST_GROUP_ID=.*/TEST_GROUP_ID=$TEST_GROUP_ID/" .env
    echo -e "${GREEN}.env updated${NC}"
else
    echo -e "${RED}.env file not found${NC}"
    exit 1
fi

# Set permissions
echo ""
echo -e "${YELLOW}[4/5] Setting file permissions...${NC}"
sudo chown -R test-ssh:clp .
find . -type d -exec sudo chmod 750 {} \;
find . -type f -exec sudo chmod 640 {} \;
chmod +x setup.sh Makefile
echo -e "${GREEN}Permissions set${NC}"

# Build containers
echo ""
echo -e "${YELLOW}[5/5] Building Docker containers...${NC}"
docker-compose build --no-cache
echo -e "${GREEN}Build complete${NC}"

echo ""
echo -e "${GREEN}========================================"
echo "Setup complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Update /etc/hosts on your local machine:"
echo "   $HOSTNAME  test.dyna.com"
echo ""
echo "2. Start containers:"
echo "   docker-compose up -d"
echo ""
echo "3. Wait 30 seconds, then install Magento:"
echo "   make install"
echo ""
echo "4. Access:"
echo "   Frontend: https://test.dyna.com/"
echo "   Admin: https://test.dyna.com/admin_12345"
echo "   phpMyAdmin: https://test.dyna.com/pma/"
echo "========================================"
