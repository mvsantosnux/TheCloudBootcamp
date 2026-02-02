#!/bin/bash
# ============================================================================
# Script de Instalação do Magento 2.4.7-p1
# Data: 2026-02-02
# Descrição: Define as variaveis para o sistema 
# ============================================================================


# Definir variáveis (ajuste os valores conforme seu ambiente)
export PUBLIC_KEY="5992ee8f47be753835a37b6ad3d1992d"
export PRIVATE_KEY="20681d9c65a2d29ce7d63d530c955fe7"
#PEGAR NO SITE DA ADOBE
export PUBLIC_IP=$(curl -s ifconfig.me)
# MySQL app user (Magento)
export MAGE_DB="magento"
export MAGE_DB_USER="magentouser"
export MAGE_DB_PASS="Strong123Password#"
# Admin do Magento
export MAGE_ADMIN_USER="admin"
export MAGE_ADMIN_PASS="Strong123Password#"
export MAGE_ADMIN_EMAIL="admin@example.com"
export MAGE_ADMIN_FIRST="Admin"
export MAGE_ADMIN_LAST="User"
# Versões (recomendadas para este lab)
export MAGENTO_VERSION="2.4.7-p4"
export PHP_V="8.2"
echo "Atualizando o sistema e instalando o Java"
sudo apt update
sudo apt -y install unzip curl git ca-certificates gnupg lsb-release software-properties-common jq openjdk-11-jdk curl wget gpg jq
sudo add-apt-repository -y ppa:ondrej/php
sudo apt update
sudo apt -y upgrade
#Instalação Apache + php
echo ">>> Instalação da Stack Web (Apache + PHP)"
sudo apt -y install apache2 libapache2-mod-fcgid
sudo a2enmod proxy_fcgi setenvif rewrite headers
###
##
#
# Otimizando o PHP ###
sudo sed -i 's/^memory_limit = .*/memory_limit = 2G/' /etc/php/${PHP_V}/cli/php.ini
sudo sed -i 's/^memory_limit = .*/memory_limit = 2G/' /etc/php/${PHP_V}/fpm/php.ini
sudo sed -i 's/^max_execution_time = .*/max_execution_time = 1800/' /etc/php/${PHP_V}/fpm/php.ini
sudo systemctl restart php${PHP_V}-fpm
#
##
### Instalação MySQL e Criação BD/Usuário para o Magento
## 
#
sudo apt -y install mysql-server
sudo systemctl enable --now mysql
# Criar DB e usuário do Magento (login como root via unix_socket)
sudo mysql -e "CREATE DATABASE ${MAGE_DB} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE USER '${MAGE_DB_USER}'@'127.0.0.1' IDENTIFIED BY '${MAGE_DB_PASS}';"

#
##
#mkdir /var/www/magento2
# Ir para diretório do Magento
#cd /var/www/magento2 || { echo "Diretório não encontrado!"; exit 1; }

# Instalar Magento (uma linha só, sem erro de sintaxe)
