#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

echo "Enter the new container name:"
read container_name

wp_container="${container_name}wp"
db_name="${container_name}db"

if [ ! -f "ports.txt" ]; then
  echo "Enter the initial HTTP port:"
  read http_port
  echo "Enter the initial HTTPS port:"
  read https_port
  echo -e "$http_port\n$https_port" > ports.txt
else
  http_port=$(head -n 1 ports.txt)
  https_port=$(tail -n 1 ports.txt)
fi

http_port=$((http_port + 1))
https_port=$((https_port + 1))
echo -e "$http_port\n$https_port" > ports.txt

# Generate a random password for WordPress and MariaDB user
password=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9')

# Generate a random password for MariaDB root user
root_password=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9')

# Create a new directory for the service
mkdir -p "./$container_name"
cat << EOF > "./$container_name/docker-compose.yml"
version: '2'
services:
  mariadb:
    container_name: $db_name
    image: docker.io/bitnami/mariadb:10.6
    restart: always
    volumes:
      - '$db_name-mariadb_data:/bitnami/mariadb'
    environment:
      - ALLOW_EMPTY_PASSWORD=no
      - MARIADB_PASSWORD=$password
      - MARIADB_USER=bn_wordpress
      - MARIADB_DATABASE=bitnami_wordpress
      - MARIADB_ROOT_PASSWORD=$root_password
  wordpress:
    container_name: $wp_container
    image: docker.io/bitnami/wordpress:6
    restart: always
    ports:
      - '$http_port:8080'
      - '$https_port:8443'
    volumes:
      - '$wp_container-wordpress_data:/bitnami/wordpress'
    depends_on:
      - mariadb
    environment:
      - ALLOW_EMPTY_PASSWORD=no
      - WORDPRESS_DATABASE_PASSWORD=$password
      - WORDPRESS_DATABASE_HOST=mariadb
      - WORDPRESS_DATABASE_PORT_NUMBER=3306
      - WORDPRESS_DATABASE_USER=bn_wordpress
      - WORDPRESS_DATABASE_NAME=bitnami_wordpress
volumes:
  $db_name-mariadb_data:
    driver: local
  $wp_container-wordpress_data:
    driver: local
EOF

cd "./$container_name"
docker-compose up -d
echo "Waiting for WordPress container to fully start up..."
sleep 60  # Wait 60 seconds. Adjust this time as necessary for your environment.
docker exec -u root $wp_container chown -R 1001:1001 /opt/bitnami/wordpress
docker exec -u root $wp_container chmod -R 755 /opt/bitnami/wordpress
docker exec -u root $wp_container chmod 660 /opt/bitnami/wordpress/wp-config.php

echo "WordPress password for $wp_container: $password"
echo "MariaDB root password for $db_name: $root_password"
