# MERN stack Pipeline on with Nginx

[![License](https://img.shields.io/npm/l/express.svg)](https://github.com/woodger/mern-pipeline/blob/master/LICENSE)

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
  reload              Hot reload all services less change ports

Options:
  -h, --help          Display more information on a specific command
  -v, --version       Print version number
  -d                  Detached mode: Run containers in the background
                      print new container names
  -p, --port          (Default: 8080) Port of listen server
  --subnet            (Default: 10.0.0.0/24) Docker subnet for
                      container networking. Already configure
  --env-file          Read in a file of environment variables
  --branch            Specify source git branch
  --api-repository    Remote or local the Api service repository
  --web-repository    Remote or local the Web service repository
  --mongo-username    (Default: admin) Create a new user and set that
                      user's password. This user is created in
                      the admin authentication database and given
                      the role of root, which is a superuser role
  --mongo-password    Use than 8 digits passphrase
                      Even a long passphrase can be quite useless
                      if it is a regular word from a dictionary.
                      Randomize letters, numbers, and symbols mixing
                      in the uppercase letters in your otherwise
                      lowercase passphrase and vice versa.

Examples:
  sh mern-pipeline.sh start -p 8080 /app
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

#### Port

Listen port. Use any free port are those from 1024 through 49151.

```sh
sh mern-pipeline.sh up \
  --port 8081 \
  --api-repository https://github.com/<api> \
  --web-repository https://github.com/<web> \
  /app
```

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
cp ./templates/mern-pipeline.service /etc/systemd/system/<example.com>.service
```

Next edit service file using any text editor. After installing new generators or updating the configuration, `systemctl daemon-reload` may be executed.

```sh
systemctl daemon-reload
```

Now try run you application in pipeline production.

```sh
systemctl start <example.com>.service
```
