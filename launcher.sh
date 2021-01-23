docker rm -f orchy || true
docker rmi orchy || true
docker build -t orchy .
docker run -d --name orchy -v /var/run/docker.sock:/var/run/docker.sock -v /usr/local/bin/docker:/usr/bin/docker -v $PWD/config:/data/config orchy