# Wudger

Разработка основана на микросервисной архитектуре.

![yuml diagram](http://yuml.me/diagram/scruffy;dir:LR/class/[Nginx]<->[Web_application{bg:yellowgreen}],[Database]<->[.NET_hypervisor{bg:lightsteelblue}],[.NET_hypervisor]<->[CDN],[Nginx]<-[CDN],[Web_application]<->[Database],[Web_application]<->[CDN],[Inc_aggregator{bg:yellow}]->[CDN],[Inc_aggregator]<->[Database],[Web_application]<->[.NET_hypervisor],[Html_parser{bg:rosybrown}]<->[Database],[Html_parser]<->[CDN])

## Руководство по началу работы

После клонирования репозитория создайте файл `./.env` с переменными окружения.

| Имя | Пример | Описание |
|-----|--------|----------|
| `MONGO_URL` | mongodb://user:pass@host:27017/collection | Параметры установки соединения с базой данных `Mongo`. |
| `MONGO_ROOT_PASSWORD`          | 1a2b3c4e | Уставливает пароль `root`, который является суперпользователем. |

### Nginx

Установка местоположения `Nginx` в качестве прокси для приложения.
Создайте файл конфигурации nginx.

**/etc/nginx/sites-available/wudger.conf**

```nginx
server {
  listen 80;
  # default_server;
  #listen [::]:80;

  server_name ref.ru www.ref.ru;

  location /robots.txt {
    alias /var/www/ref.ru/htdocs/statics/robots.txt;
  }

  return 301 https://$host$request_uri;
}

server {
  listen 443 ssl;

  server_name www.ref.ru;
  include sites-available/ssl-ref.ru.conf;
  return 301 $scheme://ref.ru$request_uri;
}

server {
  listen 443 ssl http2;

  include sites-available/ssl-ref.ru.conf;

  server_name ref.ru;
  client_max_body_size 32m;

  # less slash to tail
  location ~ .+/$ {
    rewrite (.+)/$ $1 permanent;
  }

  location ~* ^.+\..+$ {
    root /var/www/ref.ru/htdocs/statics;
    log_not_found off;
    access_log off;
  }

  location / {
    proxy_pass http://localhost:4000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_set_header IP $remote_addr;
    proxy_set_header Port $server_port;
    proxy_cache_bypass $http_upgrade;
  }

  access_log /var/www/ref.ru/logs/nginx/access.log combined;
  error_log /var/www/ref.ru/logs/nginx/error.log;
}
```
