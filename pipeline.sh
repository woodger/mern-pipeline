#!/bin/bash

if [ ! -f './.env' ]; then
  echo 'Can’t find a .env file in this directory'
  exit 1
fi

function dotenv() {
  grep $1 ./.env | egrep -v '^#'|cut -f2 -d '='
}

function repo_name {
  echo $1 | awk -F '/' '{print $NF}'
}

function free_port() {
  while :; do
    PORT=$(shuf -i 1024-49151 -n 1)
    LINE=$(lsof -i :$PORT | wc -l)
    if [ $LINE == 0 ]; then
      echo $PORT
      break
    fi
  done
}

REPO_LIST=( $(dotenv API_REPO) $(dotenv WEB_REPO) )
WEB_PORT=$(free_port)
API_PORT=$(free_port)
SUBNET=$(dotenv SUBNET)

for i in ${REPO_LIST[@]}; do
  if [ -d $(repo_name $i) ]; then
    rm -rf ./$(repo_name $i)
  fi

  git clone $i ./$(repo_name $i)
  cp -u ./.env ./$(repo_name $i)
done

mkdir -p ./nginx

cat << EOF > ./nginx/nginx.conf
server {
  listen 80;
  server_name $(dotenv DOMAIN);

  location /api {
    proxy_pass http://${SUBNET%.*}.1:$API_PORT;
  }

  location / {
    proxy_pass http://${SUBNET%.*}.1:$WEB_PORT;
  }
}
EOF

cat << EOF > ./docker-compose.yml
version: "3.3"
services:
  nginx:
    image: nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx:/etc/nginx/conf.d
    networks:
      - docker_default
  mongo:
    image: mongo
    restart: unless-stopped
    ports:
      - "27017:27017"
    environment:
      - MONGO_INITDB_ROOT_USERNAME=$(dotenv MONGO_USERNAME)
      - MONGO_INITDB_ROOT_PASSWORD=$(dotenv MONGO_PASSWORD)
    networks:
      - docker_default
  api:
    build:
      context: ./$(repo_name $(dotenv API_REPO))
    depends_on:
      - nginx
      - mongo
    restart: unless-stopped
    ports:
      - "$API_PORT:8080"
    volumes:
      - ./products:/products
    environment:
      - API_KEY=$(dotenv API_KEY)
      - MONGO_URL=${SUBNET%.*}.1:27017
      - MONGO_DB=$(dotenv MONGO_DB)
      - MONGO_USERNAME=$(dotenv MONGO_USERNAME)
      - MONGO_PASSWORD=$(dotenv MONGO_PASSWORD)
      - STORAGE_PATH=$(dotenv STORAGE_PATH)
      - OFFICE_URL=$(dotenv OFFICE_URL)
    networks:
      - docker_default
  web:
    build:
      context: ./$(repo_name $(dotenv WEB_REPO))
    depends_on:
      - api
    restart: unless-stopped
    ports:
      - "$WEB_PORT:3000"
    environment:
      - API_URL=$(dotenv API_URL)
    networks:
      - docker_default
networks:
  docker_default:
    driver: bridge
    ipam:
      driver: default
      config:
      - subnet: ${SUBNET}
EOF

docker-compose up --build
