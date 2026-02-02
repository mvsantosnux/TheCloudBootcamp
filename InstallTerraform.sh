#!/bin/bash

# Script para instalação do Terraform no Amazon Linux
# Data: 2026-02-02
# Facilitando o uso do terraform

set -e  # Encerra o script se algum comando falhar

echo "Iniciando instalação do Terraform..."

# Instala yum-utils
echo "Instalando yum-utils..."
sudo yum install -y yum-utils

# Adiciona o repositorio do terrafomr - hashicorp
echo "Adicionando repositório HashiCorp..."
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo

# Instalar Terraform
echo "Instalando Terraform... ... ... ..."
sudo yum install -y terraform

# Verifica a instalação
echo "Verificando instalação..."
terraform version

echo "Instalação concluída com sucesso!"
