#!/bin/bash

if [ ! -f './.env' ]; then
  echo 'Can’t find a .env file in this directory'
  exit 1
fi

function dotenv {
  grep $1 ./.env | egrep -v '^#'|cut -f2 -d '='
}

function free_port {
  while :; do
    PORT=$(shuf -i 1024-49151 -n 1)
    LINE=$(lsof -i :$PORT | wc -l)
    if [ $LINE == 0 ]; then
      echo $PORT
      break
    fi
  done
}

API_PORT=$(free_port)
WEB_PORT=$(free_port)
SUBNET=$(dotenv SUBNET)
GATEWAY="${SUBNET%.*}.1"

for i in ./api ./web ./nginx; do
  if [ -d $i ]; then
    rm -rf $i
  fi
done

git clone $(dotenv API_REPO) ./api

cat << EOF > ./api/.env
API_KEY=$(dotenv API_KEY)
MONGO_URL=$GATEWAY:27017
MONGO_DB=$(dotenv MONGO_DB)
MONGO_USERNAME=$(dotenv MONGO_USERNAME)
MONGO_PASSWORD=$(dotenv MONGO_PASSWORD)
OFFICE_URL=$(dotenv OFFICE_URL)
STORAGE=./storage
EOF

git clone $(dotenv WEB_REPO) ./web

cat << EOF > ./web/.env
NODE_ENV=development
API_URL=http://$(dotenv DOMAIN)
EOF

mkdir ./nginx

cat << EOF > ./nginx/nginx.conf
server {
  listen 80;
  server_name $(dotenv DOMAIN);

  location /cdn {
    root $(pwd)/storage;
  }

  location /api {
    proxy_pass http://$GATEWAY:$API_PORT;
  }

  location / {
    proxy_pass http://$GATEWAY:$WEB_PORT;
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
      context: ./api
    depends_on:
      - nginx
      - mongo
    restart: unless-stopped
    ports:
      - "$API_PORT:3000"
    volumes:
      - ./products:/products
    extra_hosts:
      - "$(dotenv DOMAIN):$GATEWAY"
    networks:
      - docker_default
  web:
    build:
      context: ./web
    depends_on:
      - api
    restart: unless-stopped
    ports:
      - "$WEB_PORT:3000"
    extra_hosts:
      - "$(dotenv DOMAIN):$GATEWAY"
    networks:
      - docker_default
networks:
  docker_default:
    driver: bridge
    ipam:
      driver: default
      config:
      - subnet: $(dotenv SUBNET)
EOF

docker-compose up --build
