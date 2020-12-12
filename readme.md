# MERN stack Pipeline on with Nginx

[![License](https://img.shields.io/npm/l/express.svg)](https://github.com/woodger/pwd-fs/blob/master/LICENSE)
[![Build Status](https://travis-ci.org/woodger/mern-pipeline.svg?branch=master)](https://travis-ci.org/woodger/mern-pipeline)

The Pipeline is an open-source framework for run SOA applications in MERN stack.

MERN (MongoDB, Express.js, React.js, Node.js) stack. Service-oriented architecture general purpose APIs that provide CRUD access to data via `http`.

![yuml diagram](http://yuml.me/diagram/scruffy;dir:LR/class/[Nginx]->[Api{bg:yellowgreen}],[Nginx]->[Web{bg:yellow}],[Api]->[Database],[Api]->[Storage{bg:lightsteelblue}])

## Getting Started

### Requirements

- [Docker Compose](https://docs.docker.com/compose/install/)
- [Lsof(8)](https://man7.org/linux/man-pages/man8/lsof.8.html)

Docker Compose uses the [Docker Engine](https://docs.docker.com/get-docker/) for any meaningful work, so make sure the Docker Engine is installed locally or remotely, depending on your setup.

### Usage

```
Usage:
  sh mern-pipeline.sh COMMAND [options] DIR
  sh mern-pipeline.sh -h|--help

The DIR parameter is a build’s context

Commands:
  start               Create and start containers
  stop                Stop services
  reload              Hot reload the Nginx service

Options:
  -h, --help          Show this help
  -v, --version       Print version number
  -d                  Detached mode: Run containers in the background
                      print new container names
  --domain            Server name (default: localhost)
  --subnet            Docker subnet for container networking
                      already configure. (default: 10.0.0.0/24)
  --env-file          Read in a file of environment variables
  --branch            Specify source git branch
  --api-repository    Remote or local the Api service repository
  --web-repository    Remote or local the Web service repository
  --mongo-username    Create a new user and set that user's password.
                      This user is created in the admin authentication
                      database and given the role of root, which
                      is a superuser role (default: admin)
  --mongo-password    Use than 8 digits passphrase
                      Even a long passphrase can be quite useless
                      if it is a regular word from a dictionary.
                      Randomize letters, numbers, and symbols mixing
                      in the uppercase letters in your otherwise
                      lowercase passphrase and vice versa.

Examples:
  sh mern-pipeline.sh start --domain example.com /app
  sh mern-pipeline.sh stop /app
```

### Configuration options

#### NODE_ENV

Setting and reading the `NODE_ENV` environment variable. For this, before starting the Pipeline, you need to add an export `NODE_ENV` using shell variable.

```sh
NODE_ENV=development sh mern-pipeline.sh up \
  --api-repository https://github.com/<api> \
  --web-repository https://github.com/<web> \
  /app
```

#### Domain

Transfer server name. By default `localhost`

```sh
sh mern-pipeline.sh up \
  --domain example.com \
  --api-repository https://github.com/<api> \
  --web-repository https://github.com/<web> \
  /app
```

If you use `--domain`, so make sure the DNS is true resolved locally or remotely, depending on your setup. Setup Local DNS Using `/etc/hosts` File in Unix like systems.
For the purpose of this manual, we will be using the following domain, hostnames and IP addresses (use values that apply to your local setting).

Single run in terminal:

```sh
echo "127.0.0.1 example.com" >> /etc/hosts
```

[nslookup(1)](https://linux.die.net/man/1/nslookup)

#### Subnet

Specify custom IPAM config. Subnet `--subnet` should be in CIDR format that represents a network segment.

For example.

```sh
sh mern-pipeline.sh up \
  --subnet 10.0.0.0/16 \
  --api-repository https://github.com/<api> \
  --web-repository https://github.com/<web> \
  /app
```

#### Help

Displays help and usage instructions.

```sh
sh mern-pipeline.sh --help
```

### Unit service

You can added the MERN Pipeline in [systemd.service(5)](https://man7.org/linux/man-pages/man5/systemd.service.5.html). For this copy `mern-pipeline.service` repository located in `/etc/systemd/system/` Unix like system.
Current user need `root` permission.

```sh
cp ./templates/mern-pipeline.service /etc/systemd/system/
```

Next edit service file using any text editor. After installing new generators or updating the configuration, `systemctl daemon-reload` may be executed.

```sh
systemctl daemon-reload
```

Now try run you application in pipeline production.

```sh
systemctl start mern-pipeline
```
