#!/bin/bash
#
# ============================================================================ #
# Script de Instalação do Magento 2.4.7-p3
# Data: 2026-02-02
# Descrição: Instala Composer, configura credenciais e prepara Magento 2
# ============================================================================ #
#
set -e  # Encerra o script se algum comando falhar

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color


# Função para imprimir mensagens coloridas
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

# ============================================================================
# VARIÁVEIS DE CONFIGURAÇÃO
# ============================================================================

# Versão do Magento a ser instalada
MAGENTO_VERSION="2.4.7-p4"
export PUBLIC_KEY="5992ee8f47be753835a37b6ad3d1992d"
export PRIVATE_KEY="20681d9c65a2d29ce7d63d530c955fe7"
#PEGAR NO SITE DA ADOBE

# Obter IP público da instância (necessário para configuração do Apache)
export PUBLIC_IP=$(curl -s ifconfig.me)

# Verificar se as variáveis de credenciais estão definidas
if [ -z "$PUBLIC_KEY" ] || [ -z "$PRIVATE_KEY" ]; then
    print_error "As variáveis PUBLIC_KEY e PRIVATE_KEY devem estar definidas!"
    print_warning "Defina-as com: export PUBLIC_KEY='sua_chave_publica'"
    print_warning "               export PRIVATE_KEY='sua_chave_privada'"
    exit 1
fi

print_message "Iniciando instalação do Magento ${MAGENTO_VERSION}..."
print_message "IP Público detectado: ${PUBLIC_IP}"

# ============================================================================
# INSTALAÇÃO DO COMPOSER
# ============================================================================

print_message "Instalando Composer..."

# Baixa o instalador do Composer diretamente para composer-setup.php
sudo php -r "copy 'https://getcomposer.org/installer', 'composer-setup.php'"

# Executa o instalador e coloca o binário em /usr/local/bin com nome 'composer'
# --install-dir: diretório de instalação
# --filename: nome do arquivo executável
sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer

# Remove o arquivo de instalação
sudo rm composer-setup.php

# Verifica a instalação
composer --version

# ============================================================================
# CONFIGURAÇÃO DE CREDENCIAIS DO MAGENTO
# ============================================================================

print_message "Configurando credenciais do repositório Magento..."

# Configura autenticação HTTP Basic para o repositório repo.magento.com
# Necessário para baixar pacotes do Magento Commerce
composer config --global http-basic.repo.magento.com $PUBLIC_KEY $PRIVATE_KEY

# ============================================================================
# PREPARAÇÃO DO DIRETÓRIO DO MAGENTO
# ============================================================================

print_message "Preparando diretório /var/www/magento2..."

# Cria o diretório base do Magento
sudo mkdir -p /var/www/magento2

# Define o usuário atual como proprietário, grupo www-data para o Apache
# $USER: variável de ambiente com o usuário atual
sudo chown -R $USER:www-data /var/www/magento2

# Navega para o diretório
cd /var/www/magento2

# ============================================================================
# DOWNLOAD DO MAGENTO VIA COMPOSER
# ============================================================================

print_message "Baixando Magento ${MAGENTO_VERSION}... (isso pode demorar)"

# Remove limite de memória do Composer para evitar erro "out of memory"
export COMPOSER_MEMORY_LIMIT=-1

# Cria projeto Magento usando metapackage oficial
# --repository-url: repositório oficial do Magento
# magento/project-community-edition: pacote da versão Open Source
# ${MAGENTO_VERSION}: versão específica a instalar
# . : instala no diretório atual
composer create-project --repository-url=https://repo.magento.com/ \
  magento/project-community-edition=${MAGENTO_VERSION} .

# ============================================================================
# VERIFICAÇÃO DA INSTALAÇÃO
# ============================================================================

print_message "Verificando instalação..."

# Exibe a versão instalada do composer.json
cat /var/www/magento2/composer.json | grep version

# Lista os vendors instalados
ls /var/www/magento2/vendor/

# ============================================================================
# CONFIGURAÇÃO DE PERMISSÕES
# ============================================================================

print_message "Configurando permissões de arquivos e diretórios..."

# Define permissão 664 (rw-rw-r--) para ARQUIVOS em diretórios críticos
# var: cache, logs, sessões
# generated: código gerado automaticamente
# pub/static: assets estáticos
# pub/media: uploads de mídia
# app/etc: configurações
sudo find var generated vendor pub/static pub/media app/etc -type f -exec chmod 664 {} \;

# Define permissão 775 (rwxrwxr-x) para DIRETÓRIOS
sudo find var generated vendor pub/static pub/media app/etc -type d -exec chmod 775 {} \;

# Torna o binário bin/magento executável
sudo chmod u+x bin/magento

# Define www-data como proprietário (usuário do Apache/PHP-FPM)
sudo chown -R www-data:www-data /var/www/magento2

# Define permissões base
sudo chmod -R 755 /var/www/magento2

# Permissões 777 para diretórios que precisam escrita total
# var: cache, logs, sessões precisam ser escritos pelo Magento
# pub: arquivos estáticos e mídia
sudo chmod -R 777 /var/www/magento2/var /var/www/magento2/pub

# ============================================================================
# CONFIGURAÇÃO DO VIRTUAL HOST APACHE
# ============================================================================

print_message "Configurando Virtual Host do Apache..."

# Cria arquivo de configuração do Apache para Magento
# tee: escreve conteúdo no arquivo
# <<'EOF': heredoc, permite texto multilinha
# 'EOF': aspas simples evitam expansão de variáveis neste bloco
sudo tee /etc/apache2/sites-available/magento.conf >/dev/null <<'EOF'
<VirtualHost *:80>
    # Nome do servidor (será substituído pelo IP público)
    ServerName PUBLIC_IP_PLACEHOLDER
    
    # Diretório raiz aponta para /pub (recomendação oficial Magento)
    DocumentRoot /var/www/magento2/pub

    # Configurações do diretório
    <Directory /var/www/magento2/pub>
        # Permite .htaccess sobrescrever configurações
        AllowOverride All
        # Permite acesso a todos
        Require all granted
    </Directory>

    # Processa arquivos PHP através do PHP-FPM via socket Unix
    # Mais eficiente que mod_php
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/php8.2-fpm.sock|fcgi://localhost/"
    </FilesMatch>

    # Logs do Apache
    ErrorLog ${APACHE_LOG_DIR}/magento_error.log
    CustomLog ${APACHE_LOG_DIR}/magento_access.log combined
</VirtualHost>
EOF

# Substitui o placeholder PUBLIC_IP_PLACEHOLDER pelo IP real
# sed -i: edita arquivo in-place
sudo sed -i "s/PUBLIC_IP_PLACEHOLDER/${PUBLIC_IP}/" /etc/apache2/sites-available/magento.conf

# Desabilita o site padrão do Apache
sudo a2dissite 000-default.conf

# Habilita o site do Magento
sudo a2ensite magento.conf

# Recarrega configuração do Apache sem derrubar conexões ativas
sudo systemctl reload apache2

# ============================================================================
# FINALIZAÇÃO
# ============================================================================

print_message "============================================"
print_message "Instalação concluída com sucesso!"
print_message "============================================"
print_message ""
print_message "Próximos passos:"
print_message "1. Acesse: http://${PUBLIC_IP}"
print_message "2. Execute o instalador web do Magento"
print_message "3. Ou instale via CLI:"
print_message "   cd /var/www/magento2"
print_message "   sudo -u www-data bin/magento setup:install \\"
print_message "     --base-url=http://${PUBLIC_IP} \\"
print_message "     --db-host=localhost \\"
print_message "     --db-name=magento \\"
print_message "     --db-user=magento_user \\"
print_message "     --db-password=sua_senha \\"
print_message "     --admin-firstname=Admin \\"
print_message "     --admin-lastname=User \\"
print_message "     --admin-email=admin@example.com \\"
print_message "     --admin-user=admin \\"
print_message "     --admin-password=Admin@123 \\"
print_message "     --language=pt_BR \\"
print_message "     --currency=BRL \\"
print_message "     --timezone=America/Sao_Paulo \\"
print_message "     --use-rewrites=1"
print_message ""
print_message "Logs do Apache:"
print_message "  - Erros: /var/log/apache2/magento_error.log"
print_message "  - Acesso: /var/log/apache2/magento_access.log"
