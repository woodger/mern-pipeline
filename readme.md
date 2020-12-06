# Wudger

## Сервис-ориентированная архитектура

API общего назначения, предоставляющие CRUD-доступ к данным через `https`.

![yuml diagram](http://yuml.me/diagram/scruffy;dir:LR/class/[Nginx]<->[Web{bg:yellowgreen}],[Nginx]<->[Ftp],[Web]<->[Database],[Web]<->[Dth{bg:lightsteelblue}],[Web]<->[Ftp],[Aggregator{bg:rosybrown}]<->[Database])

## Руководство по началу работ

После клонирования репозитория создайте файл `./.env` с переменными окружения.

<!-- | Имя | Описание |
|-----|----------|
| `Database_URL` | Параметры установки соединения с базой данных `Database` |
| `Database_ROOT_USERNAME` | Создает нового пользователя и получает роль `root` |
| `Database_ROOT_PASSWORD` | Уставливает пароль `root` пользователя | -->

## Docker Compose

Для организации подключения к внешним ресурсам для `тестирования` и` разработки` рекомендуется использовать `Docker Compose`.

В терминале введите:

```bash
docker-compose up
```

Docker Compose использует Docker Engine для любой значимой работы, поэтому убедитесь, что Docker Engine установлен локально или удаленно, в зависимости от ваших настроек.

## Юнит

```
sudo nano /etc/systemd/system/wudger.service
sudo systemctl daemon-reload
```
