# Wudger

## Сервис-ориентированная архитектура

API общего назначения, предоставляющие CRUD-доступ к данным через `https`.

![yuml diagram](http://yuml.me/diagram/scruffy;dir:LR/class/[Nginx]<->[Web{bg:yellowgreen}],[Nginx]<->[Cdn],[Web]<->[Database],[Web]<->[Dth{bg:lightsteelblue}],[Web]<->[Cdn],[Aggregator{bg:rosybrown}]<->[Database],[Ftp]<->[Cdn])

## Руководство по началу работы

После клонирования репозитория создайте файл `./.env` с переменными окружения.

<!-- | Имя | Описание |
|-----|----------|
| `Database_URL` | Параметры установки соединения с базой данных `Database` |
| `Database_ROOT_USERNAME` | Создает нового пользователя и получает роль `root` |
| `Database_ROOT_PASSWORD` | Уставливает пароль `root` пользователя | -->
