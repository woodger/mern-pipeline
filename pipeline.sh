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

function reponame {
  echo $(dotenv $i) | awk -F '/' '{print $NF}'
}

API_PORT=$(free_port)
WEB_PORT=$(free_port)
SUBNET=$(dotenv SUBNET)
GATEWAY="${SUBNET%.*}.1"

# for i in ./api ./web ./nginx; do
#   if [ -d $i ]; then
#     rm -rf $i
#   fi
#
#   mkdir $i
# done

for i in storage nginx; do
  mkdir -p ./$i
done

for i in API_REPO WEB_REPO; do
  if [ ! -d ./$(reponame $i) ]; then
    git clone $(dotenv $i)
  fi
done

cat << EOF > ./$(reponame API_REPO)/.env
NODE_ENV=development
API_KEY=$(dotenv API_KEY)
MONGO_URL=$GATEWAY:27017
MONGO_DB=$(dotenv MONGO_DB)
MONGO_USERNAME=$(dotenv MONGO_USERNAME)
MONGO_PASSWORD=$(dotenv MONGO_PASSWORD)
OFFICE_URL=$(dotenv OFFICE_URL)
EOF

cat << EOF > ./$(reponame WEB_REPO)/.env
NODE_ENV=development
API_URL=http://$(dotenv DOMAIN)
EOF

PROXY=$(
cat << EOF
  proxy_http_version 1.1;
  proxy_set_header Host $(dotenv DOMAIN);
  proxy_set_header Origin \$scheme://\$host;
EOF
)

cat << EOF > ./nginx/nginx.conf
server {
  listen 80;
  server_name $(dotenv DOMAIN);

  gzip on;
  gzip_types text/plain text/css application/javascript application/json application/msword image/svg+xml image/png image/jpeg image/gif;

  location /api {
    try_files \$uri @api;
    root /var/storage;
  }

  location / {
    try_files \$uri @web;
    root /var/static;
  }

  location @api {
    proxy_pass http://$GATEWAY:$API_PORT;
    $PROXY
  }

  location @web {
    proxy_pass http://$GATEWAY:$WEB_PORT;
    $PROXY
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
      - ./storage:/var/storage
      - ./$(reponame WEB_REPO)/static:/var/static
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
      context: ./$(reponame API_REPO)
    depends_on:
      - nginx
      - mongo
    restart: unless-stopped
    ports:
      - "$API_PORT:3000"
    extra_hosts:
      - "hyper-office.ru:$GATEWAY"
    volumes:
      - ./storage:/app/storage
      - ./products:/products
    networks:
      - docker_default
  web:
    build:
      context: ./$(reponame WEB_REPO)
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
