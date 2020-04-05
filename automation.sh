#!/bin/bash

readonly NAME='test_postgres'
readonly PASSWORD='password'
readonly HOST='0.0.0.0'
readonly PORT='5432'
readonly USER='postgres'
readonly DB='temp'

readonly DEVNULL='/dev/null'

readonly URL='https://public.bitbank.cc'

function healthcheck() {
  PGPASSWORD=$PASSWORD psql -h $HOST -U $USER -c '\l' > $DEVNULL 2>&1 || return 1
  return 0
}

function usage() {
  echo "please install psql, jq, and curl"
  exit 1
}

# check requirements
for libName in psql jq curl; do
  which $libName > $DEVNULL || usage
done

# remove existing container
exist=$(docker ps -a | grep $NAME | wc -l | sed 's/ //g')
if [[ $exist = 1 ]]; then
  docker stop $NAME > $DEVNULL && docker rm $NAME > $DEVNULL
  echo "existing container $NAME removed"
fi

# startup postgres
docker run -it -d -p $PORT:$PORT --name $NAME -e POSTGRES_PASSWORD=$PASSWORD postgres:latest > $DEVNULL

# wait for container running up
while true; do
  sleep 0.1 &&  healthcheck || continue
  break
done

# (temporary) preparation postgres
PGPASSWORD=$PASSWORD psql -h $HOST -U $USER -c "create database $DB"
PGPASSWORD=$PASSWORD psql -h $HOST -U $USER -d $DB << EOF
  create table fruit (id serial PRIMARY KEY, name text, price integer);
  insert into fruit (name, price) values ('apple', 100), ('orange', 200), ('lemon', 300);
EOF

data=$(curl -s $URL | jq '.data | .code')
echo $data

PGPASSWORD=$PASSWORD psql -h $HOST -U $USER -d $DB << EOF
update fruit set price = ${data} where name = 'apple';
update fruit set price = ${data} where name = 'orange';
EOF

for i in {1..3} ; do
PGPASSWORD=$PASSWORD psql -h $HOST -U $USER -d $DB << EOF
select name, price from fruit where id = ${i};
EOF
done

