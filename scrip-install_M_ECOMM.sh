#!/bin/bash
# Verificar Java
echo "=== Verificando Java ==="
java -version || { echo "❌ Java não encontrado. Instale o Java primeiro."; exit 1; }

# Download direto do OpenSearch
echo "=== Baixando OpenSearch 2.12.0 ==="
cd /tmp
wget -O opensearch-2.12.0-linux-x64.deb https://artifacts.opensearch.org/releases/bundle/opensearch/2.12.0/opensearch-2.12.0-linux-x64.deb

# Verificar se o download foi bem-sucedido
if [ ! -f "opensearch-2.12.0-linux-x64.deb" ]; then
    echo "❌ Falha no download do OpenSearch"
    exit 1
fi

# Instalar OpenSearch
echo "=== Instalando OpenSearch ==="
sudo OPENSEARCH_INITIAL_ADMIN_PASSWORD='Mag3nt0!Admin2025' dpkg -i opensearch-2.12.0-linux-x64.deb

# Corrigir dependências se necessário
sudo apt-get install -f -y

# Verificar instalação
if [ ! -f /etc/opensearch/opensearch.yml ]; then
    echo "❌ Falha na instalação do OpenSearch"
    exit 1
fi

# Corrigir possível problema de pós-instalação
if dpkg -l | grep opensearch | grep -q "iF"; then
    echo "=== Corrigindo estado do pacote ==="
    sudo mv /var/lib/dpkg/info/opensearch.postinst /var/lib/dpkg/info/opensearch.postinst.bak 2>/dev/null || true
    sudo dpkg --configure opensearch
fi

echo "✅ OpenSearch instalado com sucesso"

# Configuração para laboratório (Security Plugin desativado)
echo "=== Configurando para ambiente de laboratório ==="

# Backup da configuração original
sudo cp /etc/opensearch/opensearch.yml /etc/opensearch/opensearch.yml.original

# Criar configuração limpa para lab
sudo tee /etc/opensearch/opensearch.yml > /dev/null << 'EOF'
# OpenSearch Lab Configuration - Security Disabled
cluster.name: opensearch-lab
node.name: lab-node-1
network.host: 127.0.0.1
http.port: 9200
discovery.type: single-node
plugins.security.disabled: true
path.data: /var/lib/opensearch
path.logs: /var/log/opensearch
bootstrap.memory_lock: false
logger.level: INFO
EOF

# Configurar JVM para ambiente limitado
sudo tee /etc/opensearch/jvm.options.d/memory.options > /dev/null << 'EOF'
-Xms512m
-Xmx1g
EOF

# Verificar e criar usuário se necessário
if ! id opensearch >/dev/null 2>&1; then
    sudo useradd -r -s /bin/false -d /usr/share/opensearch opensearch
fi

# Configurar permissões
echo "=== Configurando permissões ==="
sudo chown -R opensearch:opensearch /etc/opensearch
sudo chown -R opensearch:opensearch /var/lib/opensearch
sudo chown -R opensearch:opensearch /var/log/opensearch
sudo chown -R opensearch:opensearch /usr/share/opensearch

# Criar diretórios necessários
sudo mkdir -p /var/run/opensearch
sudo chown opensearch:opensearch /var/run/opensearch

# Corrigir service file se necessário
if ! grep -q "ExecStart=/usr/share/opensearch/bin/opensearch" /usr/lib/systemd/system/opensearch.service 2>/dev/null; then
    echo "=== Corrigindo service file ==="
    sudo tee /usr/lib/systemd/system/opensearch.service > /dev/null << 'EOF'
[Unit]
Description=OpenSearch
Documentation=https://opensearch.org/docs/latest
Wants=network-online.target
After=network-online.target

[Service]
Type=notify
RuntimeDirectory=opensearch
PrivateTmp=true
Environment=OPENSEARCH_HOME=/usr/share/opensearch
Environment=OPENSEARCH_PATH_CONF=/etc/opensearch
Environment=PID_DIR=/var/run/opensearch
Environment=OPENSEARCH_SD_NOTIFY=true

WorkingDirectory=/usr/share/opensearch
User=opensearch
Group=opensearch
ExecStart=/usr/share/opensearch/bin/opensearch

StandardOutput=journal
StandardError=inherit
LimitNOFILE=65535
LimitNPROC=4096
LimitAS=infinity
LimitFSIZE=infinity
TimeoutStopSec=0
KillSignal=SIGTERM
KillMode=process
SendSIGKILL=no
SuccessExitStatus=143
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
EOF
fi

# Habilitar e iniciar serviço
echo "=== Iniciando OpenSearch ==="
sudo systemctl daemon-reload
sudo systemctl enable --now opensearch

# Aguardar inicialização
echo "Aguardando OpenSearch inicializar..."
sleep 20

# Teste de funcionamento
echo "=== Testando OpenSearch ==="
for i in {1..5}; do
    if curl -s http://127.0.0.1:9200 | jq . 2>/dev/null; then
        echo "✅ OpenSearch funcionando corretamente!"
        echo ""
        echo "Acesso local: <http://127.0.0.1:9200>"
        echo "Security Plugin: DESATIVADO (ideal para laboratório)"
        break
    else
        if [ $i -eq 5 ]; then
            echo "❌ OpenSearch não está respondendo"
            echo ""
            echo "Status do serviço:"
            sudo systemctl status opensearch --no-pager -l
            echo ""
            echo "Logs recentes:"
            sudo journalctl -u opensearch --no-pager -n 10
        else
            echo "Tentativa $i/5 - aguardando..."
            sleep 10
        fi
    fi
done

# Limpeza
echo "=== Limpando arquivos temporários ==="
rm -f /tmp/opensearch-*.deb

echo ""
echo "=== Instalação concluída ==="
echo "OpenSearch está rodando em: <http://127.0.0.1:9200>"
echo "Para gerenciar o serviço:"
echo "  sudo systemctl start opensearch"
echo "  sudo systemctl stop opensearch"
echo "  sudo systemctl restart opensearch"
echo "  sudo systemctl status opensearch"