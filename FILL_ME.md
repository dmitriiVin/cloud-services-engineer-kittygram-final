# Что и где нужно заполнить (Kittygram: Docker + CI/CD)

Ниже — подробная пошаговая инструкция что создать и что вписать, чтобы:
- автотесты Практикума прошли;
- push в `main` собирал образы и деплоил проект на ВМ.

## Шаг 0. Проверьте, что нужные файлы уже есть в репозитории

В проекте должны быть:
- `docker-compose.production.yml`
- `kittygram_workflow.yml`
- `.github/workflows/main.yml`
- `backend/Dockerfile`
- `frontend/Dockerfile`
- `nginx/Dockerfile`
- `nginx/nginx.conf`
- `tests.yml` (заполнить ниже)

## Шаг 1. Заполните `tests.yml` (это читает автопроверка)

Откройте файл:
- `tests.yml`

И заполните:
- `repo_owner:` — логин на GitHub (например, `your_github_login`)
- `dockerhub_username:` — логин Docker Hub (например, `your_dockerhub_login`)
- `kittygram_domain:` — ссылка на ваш проект, который будет доступен из интернета

Примеры `kittygram_domain`:
- если IP ВМ: `http://203.0.113.10` (порт `:80` можно не указывать)
- если домен: `http://kittygram.example.com` или `https://kittygram.example.com`

Важно:
- ссылка должна начинаться с `http` (иначе тесты упадут);
- после деплоя по этой ссылке должна открываться страница с текстом `Kittygram`.

## Шаг 2. Подготовьте Docker Hub (чтобы тесты увидели образы)

1) Зарегистрируйтесь/войдите в Docker Hub.
2) Убедитесь, что у вас есть публичные репозитории (или они создадутся автоматически при первом push):
   - `kittygram_backend`
   - `kittygram_frontend`
   - `kittygram_gateway`

Какие образы в итоге должны существовать и быть публичными (это проверяют тесты):
- `${DOCKERHUB_USERNAME}/kittygram_backend:latest`
- `${DOCKERHUB_USERNAME}/kittygram_frontend:latest`
- `${DOCKERHUB_USERNAME}/kittygram_gateway:latest`

3) Создайте токен Docker Hub (его кладём в GitHub Secrets как `DOCKERHUB_TOKEN`):
- обычно это **Account Settings → Security → New Access Token**;
- права — достаточно на push/pull (название токена любое, например `github-actions`).

## Шаг 3. Подготовьте сервер (ВМ)

Ниже команды ориентированы на Ubuntu/Debian. Выполняйте их на сервере по SSH.

### 3.1. Установите Docker и Compose

Проверьте:
- `docker --version`
- `docker-compose version`

Если не установлено — установите Docker и плагин Compose (способ зависит от вашей ОС/образа ВМ).

- `sudo apt install docker`

### 3.2. Откройте порты

В правилах фаервола/группы безопасности откройте входящие:
- `80/tcp` (обязательно)
- `443/tcp` (если делаете HTTPS)

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload
```

### 3.3. Подготовьте папку под деплой

Workflow копирует `docker-compose.production.yml` в папку `kittygram` в домашней директории пользователя,
под которым вы подключаетесь по SSH. На сервере создайте:
- `mkdir -p ~/kittygram`

### 3.4. Убедитесь, что ваш SSH-пользователь может выполнять `sudo` без пароля

```bash
sudo visudo
```

В конец файла добавить и заменить username на имя пользователя:

```bash
username ALL=(ALL) NOPASSWD:ALL
```

В workflow деплой делается через:
- `sudo docker-compose ...`

Если `sudo` на сервере спрашивает пароль — деплой из GitHub Actions упадёт.

## Шаг 4. Подготовьте SSH-ключ для GitHub Actions

Это нужно, чтобы GitHub Actions смог зайти на вашу ВМ по SSH.

### 4.1. На своём компьютере создайте ключ

Пример (macOS/Linux):
- `ssh-keygen -t ed25519 -C "github-actions-kittygram" -f ~/.ssh/kittygram_github_actions`

В результате появятся файлы:
- `~/.ssh/kittygram_github_actions` (приватный ключ) → это пойдёт в GitHub Secret `SSH_KEY`
- `~/.ssh/kittygram_github_actions.pub` (публичный ключ) → это добавляем на сервер

### 4.2. Добавьте публичный ключ на сервер

Самый простой способ:
- `ssh-copy-id -i ~/.ssh/kittygram_github_actions.pub <USER>@<HOST>`

Либо вручную добавьте содержимое `.pub` в файл:
- `~/.ssh/authorized_keys` на сервере

## Шаг 5. Заполните GitHub Secrets (самый частый источник ошибок)

Откройте ваш репозиторий на GitHub и зайдите:
- **Settings → Secrets and variables → Actions → New repository secret**

Добавьте секреты (имена должны совпасть 1:1):

### 5.1. Docker Hub
- `DOCKERHUB_USERNAME` — ваш логин Docker Hub
- `DOCKERHUB_TOKEN` — токен Docker Hub (см. шаг 2)

### 5.2. Сервер (SSH)
- `HOST` — IP или домен вашей ВМ (например, `203.0.113.10`)
- `USER` — SSH-пользователь (часто `ubuntu`)
- `SSH_KEY` — приватный ключ целиком (с `-----BEGIN...` до `-----END...`)

### 5.3. База/Джанго
- `POSTGRES_DB` — например `kittygram`
- `POSTGRES_USER` — например `kittygram_user`
- `POSTGRES_PASSWORD` — пароль к БД
- `DJANGO_SECRET_KEY` — любой длинный секрет (строка)

### 5.4. Telegram (опционально)
Уведомления в Telegram отключены в текущем workflow. Если захотите вернуть — нужно
добавить job `notify` и секреты `TELEGRAM_TOKEN`/`TELEGRAM_TO`.

## Шаг 6. Запуск CI/CD: что должно произойти

1) Сделайте push в ветку `main`.
2) GitHub Actions должен:
   - собрать и запушить 3 Docker-образа в Docker Hub (`latest`);
   - скопировать `docker-compose.production.yml` на сервер в папку `~/kittygram`;
   - создать на сервере файл `~/kittygram/.env` из GitHub Secrets;
   - выполнить `docker-compose pull` и `docker-compose up -d`;
   - (опционально) отправить уведомление.

Где смотреть ошибки:
- вкладка **Actions** в GitHub репозитории → последний workflow run → раскрывайте шаги с ошибками.

## Шаг 7. Быстрая самопроверка после деплоя

Проверки (в браузере и/или через curl):
- Главная: откройте `kittygram_domain` → на странице должен быть текст `Kittygram`.
- Статика: должен открываться файл вида `.../static/js/...`.
- API: `POST <kittygram_domain>/api/users/` должен вернуть `400` и JSON с полем `password`.

Если главная открывается, но API нет — чаще всего проблема в проксировании gateway (nginx) или в том,
что контейнер `backend` не поднялся (смотрите логи на сервере).

## Примечание: где лежат шаблоны переменных

Шаблон `.env`:
- `_env.example`

Production compose:
- `docker-compose.production.yml`
