#### Mollusk ![](https://img.shields.io/badge/Status-Completed-008000.svg?style=plastic)

```
mkdir docker && cd docker
git clone https://github.com/TundraFizz/Mollusk .
bash setup.sh
bash mollusk.sh compose

git clone https://github.com/TundraFizz/Docker-Sample-App
docker build -t sample-app Docker-Sample-App

Modify the docker-compose.yml file to include your images

docker swarm init
docker stack deploy -c docker-compose.yml sample
bash mollusk.sh ssl -d mudki.ps -se sample-app -st sample -s
```
