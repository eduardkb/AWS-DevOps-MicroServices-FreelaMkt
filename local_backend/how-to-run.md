# Local Backend (Lambda + Database)

## In WSL

- Make sure you have Ubuntu24.04 in WSL
- docker installed
- python installed
- sam installed (for AWS Lambda run)
    - sudo apt update 
    - sudo apt install unzip curl -y
    - curl -Lo aws-sam-cli-linux-x86_64.zip https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip
    - unzip aws-sam-cli-linux-x86_64.zip -d sam-installation
    - sudo ./sam-installation/install
    - sam --version

## PosgtgreSQL

- postgre runs on docker with compose file `docker-compose.yml`
- execute: $> docker compose up -d

## Lambda

- create python venv with
    - $> python -m venv venv