# Mollusk ![](https://img.shields.io/badge/Status-Completed-008000.svg?style=plastic)

Setup my Docker environment using Mollusk

```
mkdir docker && cd docker
git clone https://github.com/TundraFizz/Mollusk .
bash setup.sh
```

Clone and build an example project

```
git clone https://github.com/TundraFizz/Docker-Sample-App
docker build -t sample-app Docker-Sample-App
```

Modify the docker-compose.yml file to include your images

```
docker stack deploy -c docker-compose.yml sample
bash mollusk.sh ssl -d mudki.ps -se sample-app -st sample -s
```
