#!/usr/bin/bash

# healthcheck vars
boottime=10
interval=15
retries=2
timeout=1

# declare variables
# containers -> associative array of startup processes
declare -A containers
# dependencies -> associative array of dependencies
declare -A dependency
# tasks -> associative array with tasks
# timers -> kind of constant we the configured timers for each task are stored
# counters -> init&reset to timers, it's used as a purely decremental counter
declare -A tasks
declare -A timers
declare -A counters

# init.conf
# it is not verifying whether the conf file is well-formated
section=""
while read -r l; do
    if [[ "$l" == "-> containers" ]]; then
        section="containers"
    elif [[ "$l" == "-> tasks" ]]; then
        section="tasks"
    elif [[ "$l" == "-> vars" ]]; then
        section="vars"
    fi
    if [[ $section == "containers" ]]; then
        if [[ "$l" == "name"* ]]; then
            name=${l#"name:"}
        elif [[ "$l" == "startup_process"* ]]; then
            containers[$name]=${l##"startup_process:"}
        elif [[ "$l" == "dependencies"* ]]; then
            dependency[$name]=${l##"dependencies:"}
        fi
    elif [[ $section == "tasks" ]]; then
        if [[ "$l" == "name"* ]]; then
            name=${l#"name:"}
        elif [[ "$l" == "definition"* ]]; then
            tasks[$name]=${l##"definition:"}
        elif [[ "$l" == "frequency"* ]]; then
            timers[$name]=${l##"frequency:"}
            counters[$name]=${l##"frequency:"}
        fi
    elif [[ $section == "vars" ]]; then
        if [[ "$l" == "boottime"* ]]; then
            boottime=${l#"boottime:"}
        elif [[ "$l" == "interval"* ]]; then
            interval=${l#"interval:"}          
        elif [[ "$l" == "retries"* ]]; then
            retries=${l#"retries:"}
        elif [[ "$l" == "timeout"* ]]; then
            timeout=${l#"timeout:"}
        fi
    fi
done < config/init.conf

# helpers
start_container() {
    container_name=$1
    if [[ $(docker ps | grep $container_name | wc -l) -eq 0 ]]; then
        source ${containers[$container_name]}
        echo "$container_name is now running"
    fi
}

monit_container() {
    container_name=$1
    threshold=0
    # perhaps it's better to wait until status is up but it could cause a infinite loop
    while ([ $(docker ps -f "name=$container_name" --format {{.Status}} | grep Up | wc -l) -eq 0 ] &&  [ $threshold -lt $retries ]); do
        aux_cmd="sleep ${timeout}s"
        eval ${aux_cmd}
        ((threshold+=1))
    done
    # return 1 whether we have been able to bring up the container in timely fashion, otherwise return 0
    if [[ $threshold -ge $retries ]]; then
        echo 0
    else
        echo 1
    fi
}

kill_container() {
    container_name=$1
    docker rm -f $container_name
    echo "Container $container_name killed by dependencies down"
}

# general bootstrap process - kind of portfast bring up everything as quick as possible
echo "Booting the services"
for key in "${!containers[@]}"; do
    echo "bringing up $key"
    start_container $key
done

# Start waiting for bootstrapping (maybe something more detailed may be done)
sleep ${boottime}s
# constant monitoring process + task manager execution
echo "Orchy starts swimming around"
while true; do
    echo "=========================================="
    echo "#      Sentinel is looking around        #"
    echo "=========================================="
    for key in "${!containers[@]}"; do
        echo "Check dependencies of: $key"    
        IFS=',' read -a depa <<< "${dependency[$key]}"
        # must be stopped once the first dependency fails when multiple dependencies
        if [ "${#depa[@]}" -gt 0 ]; then
            for i in "${depa[@]}"; do
                echo "->Checking dependency with: $i"
                mon="$(monit_container $i)"
                if [[ $mon -eq 0 ]]; then
                    echo "--> dependencies are not met. $i is down"
                    kill_container $key
                    break
                else
                    echo "-->dependencies are met. $i is up"
                    start_container $key
                fi
            done
        else
            start_container $key
        fi
    done
    echo "=========================================="
    echo "#        Task manager shows up           #"
    echo "=========================================="
    for key in "${!counters[@]}"; do
        echo "Check for task: $key is in process..."
        if [[ "${counters[$key]}" -le 0 ]]; then
            echo "Time to attack: $key"
            counters[$key]=${timers[$key]}
            source ${tasks[$key]}
        else
            echo "Keep swimming little $key"
            ((counters[$key]-=$interval))
        fi
    done
    # monitor every 15 seconds afterwards
    sleep ${interval}s
done