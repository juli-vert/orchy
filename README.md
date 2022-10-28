# orchy
![alt text](https://github.com/julivert82/orchy/blob/main/img/orchy.png?raw=true)  
Minimal docker-based orchestrator for stacks running within a host with dependencies between containers  
  
Running orchy with the basic example:  
>git git@github.com:juli-vert/orchy.git  
>cd orchy && chmod +x launcher.sh && chmod +x /config/scripts/* && chmod +x /config/tasks/*  
>./launcher.sh
## Monitor the process  
>docker logs orchy -f  
>watch -n 5 docker ps
## Kill containers for fun
>rm -f foo  
>rm -f bar
## Create your own stack
Check the init.conf for more detail
