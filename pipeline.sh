#!/bin/bash

# general dependencies:
#
#   docker
#   docker-compose

function cwd {
  local script exists result

  script=$(ps -o cmd $$ | tail -1 | cut -f2 -d ' ')
  exists=$(echo $script | sed -n '/\//p')
  result=$(echo ${script%/*})

  if [[ ! $exists ]] || [[ $result == '.' ]]; then
    pwd
    return
  fi

  echo $result
}

cd $(cwd)

function dotenv {
  grep $1 ./.env | egrep -v '^#'| cut -f2 -d '='
}

function dotenv {
  grep $1 ./.env | egrep -v '^#'| cut -f2 -d '='
}

function freeport {
  local p x

  while :; do
    p=$(shuf -i 1024-49151 -n 1)
    x=$(lsof -i :$p | wc -l)

    if [[ $x == 0 ]]; then
      echo $p
      return
    fi
  done
}

API_PORT=$(freeport)
WEB_PORT=$(freeport)
MONGO_PORT=$(freeport)
SUBNET=$(dotenv SUBNET)
GATEWAY=${SUBNET%.*}.1

if [[ ! -f ./.env ]]; then
  echo "Can’t find a .env file in $(pwd)"
  exit 1
fi

for path in ./api ./web ./nginx; do
  if [[ -d $path ]]; then
    rm -rf $path
  fi

  mkdir $path
done

git clone -b develop --single-branch $(dotenv API_REPO) ./api
git clone -b develop --single-branch $(dotenv WEB_REPO) ./web

cat << EOF > ./web/.env
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
      - ./web/static:/var/static
    networks:
      - docker_default
  mongo:
    image: mongo
    restart: unless-stopped
    ports:
      - "$MONGO_PORT:27017"
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
    extra_hosts:
      - "hyper-office.ru:$GATEWAY"
    volumes:
      - ./storage:/app/storage
      - ./products:/products
    environment:
      - NODE_ENV=development
      - API_KEY=$(dotenv API_KEY)
      - MONGO_URL=$GATEWAY:$MONGO_PORT
      - MONGO_DB=$(dotenv MONGO_DB)
      - MONGO_USERNAME=$(dotenv MONGO_USERNAME)
      - MONGO_PASSWORD=$(dotenv MONGO_PASSWORD)
      - OFFICE_URL=$(dotenv OFFICE_URL)
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
