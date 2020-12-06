#!/bin/bash

# general dependencies:
#
#   docker
#   docker-compose
#   lsof

VERSION=0.0.2
PROGNAME=$(basename $0)
CWD=$(dirname $0)

function usage {
  echo "Usage:"
  echo "  "$PROGNAME" [options] [COMMAND]"
  echo "  "$PROGNAME" -h|--help"
  echo
  echo "Options:"
  echo "  -h, --help         Show this help"
  echo "  -v, --version      Print version number"
  echo "  -d                 Detached mode: Run containers in the background"
  echo "                     print new container names"
  echo
  echo "Commands:"
  echo "  up                 Create and start containers"
  echo "  stop               Stop services"
  echo
  echo "Examples:"
  echo "  "$PROGNAME" up"
  echo "  "$PROGNAME" stop"
}

GETOPT_ARGS=$(getopt -o hvd -l "help","version" -n "$PROGNAME" -- "$@")
DETACHED=

if [[ $? -ne 0 ]]; then
  usage
  exit 1
fi

cd $CWD
eval set -- $GETOPT_ARGS

while :; do
  case $1 in
    -h|--help)
      usage
      exit
      ;;
    -v|--version)
      echo $VERSION
      exit
      ;;
    -d)
      DETACHED=$1
      shift
      ;;
    --)
      shift
      break
      ;;
  esac
done

if [[ ! $1 ]]; then
  usage
  exit 1
fi

if [[ $1 == "stop" ]]; then
  docker-compose stop
  exit
fi

function dotenv {
  grep $1 ./.env | egrep -v "^#"| cut -f2 -d "="
}

function freeport {
  local port

  while :; do
    port=$(shuf -i 1024-49151 -n 1)

    if [[ ! $(lsof -i :$port) ]]; then
      echo $port
      break
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

if [[ $1 == "up" ]]; then
  docker-compose up --build $DETACHED
  exit
fi
