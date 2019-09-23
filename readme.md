# Wudger

Разработка основана на микросервисной архитектуре.

![yuml diagram](http://yuml.me/diagram/scruffy;dir:LR/class/[Nginx]<->[Web_application{bg:yellowgreen}],[Nginx]<->[Cdn],[Mongo]<->[Dth_hypervisor{bg:lightsteelblue}],[Web_application]<->[Mongo],[Web_application]<->[Dth_hypervisor],[Aggregator{bg:rosybrown}]<->[Mongo])

## Руководство по началу работы

После клонирования репозитория создайте файл `./.env` с переменными окружения.

| Имя | Описание |
|-----|----------|
| `MONGO_URL` | Параметры установки соединения с базой данных `mongo` |
| `MONGO_ROOT_USERNAME` | Создает нового пользователя и получает роль `root` |
| `MONGO_ROOT_PASSWORD` | Уставливает пароль `root` пользователя |

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
