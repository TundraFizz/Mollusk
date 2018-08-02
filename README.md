# Mollusk ![](https://img.shields.io/badge/Status-Completed-008000.svg?style=plastic)

Setup my Docker environment using Mollusk

```sh
mkdir docker && cd docker
git clone https://github.com/TundraFizz/Mollusk .
bash setup.sh
```

After the system restarts from running `bash setup.sh` cd back into the docker folder and run the following commands

```sh
docker swarm init
bash mollusk.sh nconf -c phpmyadmin -s ip -p 9000
```

---

Clone and build an example project. For this example:

```
REPO_URL     | https://github.com/TundraFizz/Docker-Sample-App
REPO_NAME    | Docker-Sample-App
DOMAIN_NAME  | mudki.ps
SERVICE_NAME | my-app
STACK_NAME   | my-stack
```

```sh
git clone REPO_URL                                                 # Clone the repository
docker build -t SERVICE_NAME REPO_NAME                             # Build the image
bash mollusk.sh nconf -c SERVICE_NAME -s DOMAIN_NAME               # Create a basic NGINX configuration file
nano docker-compose.yml                                            # Add the service to the docker-compose.yml
nano REPO_NAME/config.yml                                          # [Optional] Configure settings
bash mollusk.sh newdb -f DB_FILE.sql -p DB_PASSWORD                # [Optional] Create a database from an SQL file
docker stack deploy -c docker-compose.yml STACK_NAME               # Deploy the Docker stack
bash mollusk.sh ssl -d DOMAIN_NAME -se SERVICE_NAME -st STACK_NAME # [Optional] Create an SSL certificate
```

Templates for `nano docker-compose.yml`

```sh
  IMAGE-NAME:
    image: IMAGE-NAME
```
```sh
  IMAGE-NAME:
    image: IMAGE-NAME
    volumes:
      - ./logs:/usr/src/app/src/logs
```
