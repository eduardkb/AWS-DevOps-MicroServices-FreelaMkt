How to Run the Local Backend in WSL (with PostgreSQL in Docker)
Architecture Overview
Windows Host
├── Frontend Flask app  →  http://localhost:5000
│       │
│       ▼
WSL (Ubuntu)
├── SAM Local API Gateway  →  port 3000
│       │  invokes
├── Lambda functions
│       │  connect via Docker network
└── PostgreSQL (Docker container) →  port 5432 (exposed)

1. Install WSL with Ubuntu
wsl --install -d Ubuntu-24.04

Restart Windows and complete Ubuntu setup.

2. Install System Dependencies in WSL
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl unzip git python3 python3-pip python3-venv python3-dev build-essential libpq-dev

3. Install Docker (PostgreSQL + SAM runtime)
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker

sudo usermod -aG docker $USER
newgrp docker

docker --version
4. Install AWS SAM CLI
cd ~
curl -Lo sam.zip https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip

unzip sam.zip -d sam-installation
sudo ./sam-installation/install
sam --version

5. Configure AWS CLI (required by SAM)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

unzip awscliv2.zip
sudo ./aws/install

aws configure
# AWS Access Key ID: local
# AWS Secret Access Key: local
# Region: us-east-1
# Output: json

6. Start PostgreSQL in Docker
6.1 Creeate new docker network
docker network create freela-net
docker network ls

6.1 Run container
docker run -d \
  --name freela-postgres \
  --network freela-net \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  postgres:16

6.2 Verify DB is running
docker ps

Install psql
sudo apt install -y postgresql-client

Test connection:
psql -h 127.0.0.1 -U postgres -d mydb -c "SELECT 1;"

Password: postgres

7. Project Setup (WSL workspace)
mkdir -p ~/dev/freelamkt
cd ~/dev/freelamkt

rm -rf ~/dev/freelamkt/{*,.*}
cp -r /mnt/c/Users/Work/Documents/dev/AWS-DevOps-MicroServices-FreelaMkt/local_backend/* .
cp -r /mnt/c/Users/Work/Documents/dev/AWS-DevOps-MicroServices-FreelaMkt/backend_api .

Optional check tree:
sudo apt install tree -y


8. Check environment variables 

Check inside local_backend/template.yaml

Environment:
      Variables: &default_env
        APP_ENV: dev
        DB_HOST: freela-postgres
        DB_PORT: "5432"
        DB_NAME: mydb
        DB_USER: postgres
        DB_PASSWORD: postgres

10. Build SAM Application

sam build --use-container

Ignore requirements.txt message. Check if requirements are installed: `ls .aws-sam/build/SharedLayer/python`. This happens because it searchs the file inside every foler. but it only exists inside shared folder which is used by all modules.

11. Run Database Migration

sam local invoke DbMigration --docker-network freela-net
Tables will be created in the Docker PostgreSQL container.

Verify if created
psql -h 127.0.0.1 -U postgres -d mydb -c "SELECT tablename FROM pg_tables WHERE schemaname = 'public';"
Verify table entries
psql -h 127.0.0.1 -U postgres -d mydb -c "SELECT * FROM users;"

12. Start API Gateway locally
sam local start-api --docker-network freela-net \
  --host 0.0.0.0 --port 3000

13. Get WSL IP (for frontend access)
hostname -I | awk '{print $1}'

Example:
172.26.123.68

Test API:
curl http://172.26.123.68:3000/api/user/healthcheck

14. Configure Windows Frontend

In frontend_webApp/.env:

API_URL=http://<WSL-IP>:3000/api

Start frontend:

cd frontend_webApp
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python run.py


16. Restart DB and API

# Start DB
docker start freela-postgres

# Start API
cd ~/dev/freelamkt/local_backend
sam local start-api --docker-network freela-net \
  --host 0.0.0.0 --port 3000 --debug
  
17. Troubleshooting
Problem	Fix
Connection refused to DB	Ensure container is running: docker ps
Auth failed	Check POSTGRES_PASSWORD in container
SAM can't reach DB	Ensure DB_HOST=host.docker.internal
Port 5432 busy	Stop local postgres if still installed
Migration fails	Check logs: docker logs freela-postgres