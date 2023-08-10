etcdset() {
    local key=$1
    local value=$2
    docker exec -it ${SAMMCONT} etcdctl --endpoint http://${ETCDIP}:2379 set $key $value 2>/dev/null
}

etcdget() {
    local key=$1
    docker exec -it ${SAMMCONT} etcdctl --endpoint http://${ETCDIP}:2379 get $key 2>/dev/null  
}

getetcdip() {
    local contname=$1
    docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${contname} 2>/dev/null
}
