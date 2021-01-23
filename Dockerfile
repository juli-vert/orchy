FROM ubuntu:latest
RUN mkdir data
WORKDIR data
COPY orch.sh . 
RUN chmod +x orch.sh
VOLUME ["/var/run/docker.sock", "/usr/bin/docker", "data/config"]
ENTRYPOINT ["./orch.sh"]