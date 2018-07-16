# Mollusk ![](https://img.shields.io/badge/Status-Completed-008000.svg?style=plastic)

Setup my Docker environment using Mollusk

```sh
mkdir docker && cd docker
git clone https://github.com/TundraFizz/Mollusk .
bash setup.sh
docker swarm init
```

Clone and build an example project

```sh
# Download the application
git clone https://github.com/TundraFizz/Docker-Sample-App

# Build the image
docker build -t sample-app Docker-Sample-App

# Modify the docker-compose.yml file to include your images
# Note: volumes is optional, but the host folder must already exist
#       the client folder will automatically be created in the container
nano docker-compose.yml

  my-application:
    image: my-application
    volumes:
      - ./aaaaaaaa:/usr/src/app/src/abc/def

# Create a basic NGINX configuration file
bash mollusk.sh nconf -c sample-app -s mudki.ps

# Deploy
docker stack deploy -c docker-compose.yml sample

# [Optional] Create an SSL certificate
bash mollusk.sh ssl -d mudki.ps -se sample-app -st sample -s
```
