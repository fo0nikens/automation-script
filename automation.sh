#!/bin/bash

readonly POSTGRES='test_postgres'

function healthcheck() {
  PGPASSWORD=password psql -h 0.0.0.0 -U postgres -c '\l' > /dev/null 2>&1 || return 1
  return 0
}

# remove existing container
exist=$(docker ps -a | grep $POSTGRES | wc -l | sed 's/ //g')
if [[ $exist = 1 ]]; then
  docker stop $POSTGRES && docker rm $POSTGRES
  echo "container $POSTGRES removed"
fi

# startup postgres
docker run -it -d -p 5432:5432 --name $POSTGRES -e POSTGRES_PASSWORD=password postgres:latest

# wait for container running up
while true; do
  sleep 0.1 &&  healthcheck || continue
  break
done

# (temporary) preparation postgres
PGPASSWORD=password psql -h 0.0.0.0 -U postgres -c 'create database temp'
PGPASSWORD=password psql -h 0.0.0.0 -U postgres -d temp << EOF
create table fruit (id serial PRIMARY KEY, name text, price integer);
insert into fruit (name, price) values ('apple', 100), ('orange', 200), ('lemon', 300);
EOF


