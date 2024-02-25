#!/bin/bash
# go to the project directory and create a .env file
cd ~/projects/

# create a .env file
touch .env

# add the following to the .env file
echo "DB_HOST=$db_host" >> .env
ec   "DB_USER=$db_user" >> .env
echo "DB_PASS=$db_pass" >> .env
echo "DB_NAME=$db_name" >> .env
echo "DB_PORT=$mysql_port" >> .env
echo "PORT=$port" >> .env