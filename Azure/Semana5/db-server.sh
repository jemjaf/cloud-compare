#!/bin/bash
sudo apt update
sudo apt upgrade -y
sudo apt install postgresql postgresql-contrib -y
sudo apt install -y postgresql
#sudo systemctl status 'postgresql*'
# Establecer la contraseña del usuario "postgres"
# sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'P@ssw0rd1234!';"
