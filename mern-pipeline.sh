#!/bin/bash

# general dependencies:
#
#   docker
#   docker-compose
#   basename
#   lsof

VERSION=3.5.14
PROGNAME=$(basename $0)

function usage {
  echo
  echo "Usage:"
  echo "  sh "$PROGNAME" COMMAND [options] DIR"
  echo "  sh "$PROGNAME" -h|--help"
  echo
  echo "The DIR parameter is a build’s context"
  echo
  echo "Commands:"
  echo "  up                  Create and start containers"
  echo "  stop                Stop services"
  echo "  reload              Hot reload all services less change ports"
  echo
  echo "Options:"
  echo "  -h, --help          Display more information on a specific command"
  echo "  -v, --version       Print version number"
  echo "  -d                  Detached mode: Run containers in the background"
  echo "                      print new container names"
  echo "  -p, --port          (Default: 8080) Port of listen server"
  echo "  --subnet            (Default: 10.0.0.0/24) Docker subnet for"
  echo "                      container networking. Already configure"
  echo "  --env-file          Read in a file of environment variables"
  echo "  --branch            Specify source git branch"
  echo "  --api-repository    Remote or local the Api service repository"
  echo "  --web-repository    Remote or local the Web service repository"
  echo "  --mssql-username    (Default: admin) Create a new user and set that"
  echo "                      user's password. This user is created in"
  echo "                      the admin authentication database and given"
  echo "                      the role of root, which is a superuser role"
  echo "  --mssql-password    Use than 8 digits passphrase"
  echo "                      Even a long passphrase can be quite useless"
  echo "                      if it is a regular word from a dictionary."
  echo "                      Randomize letters, numbers, and symbols mixing"
  echo "                      in the uppercase letters in your otherwise"
  echo "                      lowercase passphrase and vice versa."
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

function forwardport {
  docker-compose port $1 $2 | cut -f2 -d ":"
}

function signand {
  if [[ ! -f $1 ]]; then
    < /dev/urandom tr -dc A-Za-z0-9 | head -c32 > $1
  fi

  cat $1
}

BIN_PATH=$(readlink $0)
PROGNAME_CWD=$(dirname $BIN_PATH)
GETOPT_ARGS=$(getopt -o hvdp -l "help","version","subnet:","port:","env-file:","branch:","api-repository:","web-repository:","mssql-username:","mssql-password:" -n "$PROGNAME" -- "$@")

MODE=
SUBNET="10.0.0.0/24"
LISTEN_PORT=8080
BRANCH=
ENV_FILE=
API_PORT=$(freeport)
API_REPOSITORY=
WEB_PORT=$(freeport)
WEB_REPOSITORY=
MSSQL_PORT=$(freeport)
MSSQL_USERNAME="sa"
MSSQL_PASSWORD=

if [[ $? != 0 ]]; then
  usage
  exit 1
fi

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
      MODE=$1
      shift
      ;;
    --subnet)
      shift
      SUBNET=$1
      shift
      ;;
    -p|--port)
      shift
      LISTEN_PORT=$1
      shift
      ;;
    --branch)
      shift
      BRANCH=$1
      shift
      ;;
    --env-file)
      shift
      ENV_FILE=$1
      shift
      ;;
    --api-repository)
      shift
      API_REPOSITORY=$1
      shift
      ;;
    --web-repository)
      shift
      WEB_REPOSITORY=$1
      shift
      ;;
    --mssql-username)
      shift
      MSSQL_USERNAME=$1
      shift
      ;;
    --mssql-password)
      shift
      MSSQL_PASSWORD=$1
      shift
      ;;
    --)
      shift
      break
      ;;
  esac
done

if [[ ! $1 ]]; then
  echo "Expected COMMAND parameter"
  exit 1
fi

if [[ ! $2 ]]; then
  echo "Expected DIR parameter is a build’s context"
  exit 1
fi

cd $2

if [[ $1 == "stop" ]]; then
  docker-compose stop
  exit
fi

if [[ ! $SUBNET =~ [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,2} ]]
then
  echo "Expected the Docker subnet as 172.17.0.0/16 for container networking"
  exit 1
fi

GATEWAY=${SUBNET%.*}.1

if (( $LISTEN_PORT < 1024 )) || (( $LISTEN_PORT > 49151 )); then
  echo "Expected ports are those from 1024 through 49151"
  exit 1
fi

if [[ $ENV_FILE ]] && [[ ! -f $ENV_FILE ]]; then
  echo "The file specified in --env-file was not found"
  exit 1
fi

if [[ ! $API_REPOSITORY ]]; then
  echo "Parameter --api-repository is required"
  exit 1
fi

if [[ ! $WEB_REPOSITORY ]]; then
  echo "Parameter --web-repository is required"
  exit 1
fi

mkdir -p ./{nginx,mssql}

if [[ ! $MSSQL_PASSWORD ]]; then
  MSSQL_PASSWORD=$(signand ./mssql/mssql.srl)
fi

if [[ $1 == "reload" ]]; then
  API_PORT=$(forwardport api 3000)
  WEB_PORT=$(forwardport web 3000)
  MSSQL_PORT=$(forwardport mssql 1433)
fi

for item in ./api ./web; do
  if [[ -d $item ]]; then
    rm -rf $item
  fi

  mkdir $item
done

if [[ $BRANCH ]]; then
  git clone -b $BRANCH --single-branch $API_REPOSITORY ./api
  git clone -b $BRANCH --single-branch $WEB_REPOSITORY ./web
else
  git clone $API_REPOSITORY ./api
  git clone $WEB_REPOSITORY ./web
fi

if [[ ! $ENV_FILE ]] && [[ -f ./.env ]]; then
  ENV_FILE=./.env
fi

touch ./.env.$PROGNAME

if [[ -f $ENV_FILE ]]; then
  cat $ENV_FILE >> ./.env.$PROGNAME
fi

cat ./.env.$PROGNAME >> ./web/.env

cat << EOF > ./nginx/nginx.conf
server {
  listen 80;
  listen [::]:80;

  gzip on;
  gzip_types text/plain text/css application/javascript application/json image/svg+xml;

  client_max_body_size 1G;

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
  }

  location @web {
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
    depends_on:
      - web
    ports:
      - "$LISTEN_PORT:80"
    volumes:
      - ./nginx:/etc/nginx/conf.d
      - ./web/static:/var/static
      - ./storage:/var/storage
    networks:
      - docker_default

  mssql:
    build:
      context: $PROGNAME_CWD/mssql-non-root
    restart: unless-stopped
    ports:
      - "$MSSQL_PORT:1433"
    volumes:
      - ./mssql:/var/opt/mssql
    environment:
      - ACCEPT_EULA=Y
      - SA_PASSWORD=$MSSQL_PASSWORD
    networks:
      - docker_default
  api:
    build:
      context: ./api
    restart: unless-stopped
    depends_on:
      - mssql
    ports:
      - "$API_PORT:3000"
    volumes:
      - ./ca-certificates:/usr/local/share/ca-certificates
      - ./storage:/app/storage
    environment:
      - MSSQL_URL=$GATEWAY:$MSSQL_PORT
      - MSSQL_USERNAME=$MSSQL_USERNAME
      - MSSQL_PASSWORD=$MSSQL_PASSWORD
      - MSSQL_DATABASE=master
    env_file:
      - ./.env.$PROGNAME
    networks:
      - docker_default
  web:
    build:
      context: ./web
    restart: unless-stopped
    depends_on:
      - api
    ports:
      - "$WEB_PORT:3000"
    volumes:
      - ./ca-certificates:/usr/local/share/ca-certificates
    networks:
      - docker_default
networks:
  docker_default:
    driver: bridge
    ipam:
      driver: default
      config:
      - subnet: $SUBNET
EOF

if [[ $1 == "up" ]]; then
  docker-compose up --build $MODE
  exit
fi

if [[ $1 == "reload" ]]; then
  docker-compose stop
  docker-compose up --build $MODE
  exit
fi

usage
exit 1
