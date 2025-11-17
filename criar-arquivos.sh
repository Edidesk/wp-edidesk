#!/bin/bash

# Script para criar todos os arquivos do projeto wp-edidesk
# Execute este script dentro da pasta wp-edidesk

echo "🚀 Criando arquivos do projeto WordPress Edidesk..."
echo ""

# Criar Dockerfile
cat > Dockerfile << 'EOF'
# Usar a imagem oficial do WordPress como base
FROM wordpress:latest

# Informações do mantenedor
LABEL maintainer="Edidesk <contato@edidesk.com.br>"
LABEL description="WordPress customizado com configurações de PHP otimizadas - Edidesk"

# Criar diretório para configurações customizadas do PHP
RUN mkdir -p /usr/local/etc/php/conf.d

# Copiar arquivo de configurações customizadas do PHP
COPY custom-php.ini /usr/local/etc/php/conf.d/custom-php.ini

# Ajustar permissões
RUN chown -R www-data:www-data /var/www/html

# Expor porta 80
EXPOSE 80
EOF

echo "✅ Dockerfile criado"

# Criar custom-php.ini
cat > custom-php.ini << 'EOF'
; Configurações customizadas de PHP para WordPress - Edidesk

; Limites de Upload
upload_max_filesize = 256M
post_max_size = 256M

; Limites de Memória
memory_limit = 512M

; Tempo de Execução
max_execution_time = 300
max_input_time = 300

; Outras configurações úteis
max_input_vars = 5000
file_uploads = On

; Configurações de sessão
session.gc_maxlifetime = 3600
session.save_path = "/tmp"

; Logs de erros
display_errors = Off
display_startup_errors = Off
log_errors = On
error_log = /var/log/php_errors.log

; Timezone
date.timezone = America/Fortaleza

; OPcache para melhor performance
opcache.enable = 1
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 16
opcache.max_accelerated_files = 10000
opcache.revalidate_freq = 2
opcache.fast_shutdown = 1
EOF

echo "✅ custom-php.ini criado"

# Criar docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  wordpress:
    image: bartferr/wp-edidesk:latest
    container_name: wordpress-edidesk
    restart: unless-stopped
    ports:
      - "8080:80"
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: senha_segura_aqui
    volumes:
      - wordpress_data:/var/www/html
    networks:
      - wordpress_network
    depends_on:
      - db

  db:
    image: mysql:8.0
    container_name: wordpress-db
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: senha_segura_aqui
      MYSQL_ROOT_PASSWORD: senha_root_segura_aqui
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - wordpress_network
    command: '--default-authentication-plugin=mysql_native_password'

volumes:
  wordpress_data:
  db_data:

networks:
  wordpress_network:
    driver: bridge
EOF

echo "✅ docker-compose.yml criado"

# Criar .gitignore
cat > .gitignore << 'EOF'
.env
.env.local
*.log
logs/
*.sql
*.tar.gz
*.zip
backup-*
.DS_Store
Thumbs.db
.vscode/
.idea/
*.swp
EOF

echo "✅ .gitignore criado"

# Criar .dockerignore
cat > .dockerignore << 'EOF'
.git
.gitignore
docker-compose.yml
.dockerignore
README.md
*.md
*.log
logs/
.DS_Store
Thumbs.db
.vscode/
.idea/
EOF

echo "✅ .dockerignore criado"

# Criar .env.example
cat > .env.example << 'EOF'
# Configurações do WordPress
WORDPRESS_DB_HOST=db:3306
WORDPRESS_DB_NAME=wordpress
WORDPRESS_DB_USER=wordpress
WORDPRESS_DB_PASSWORD=SuaSenhaSeguraAqui123!

# Configurações do MySQL
MYSQL_DATABASE=wordpress
MYSQL_USER=wordpress
MYSQL_PASSWORD=SuaSenhaSeguraAqui123!
MYSQL_ROOT_PASSWORD=SuaSenhaRootSeguraAqui456!

# Portas
WORDPRESS_PORT=8080

# Informações da imagem
IMAGE_NAME=bartferr/wp-edidesk
IMAGE_TAG=latest
EOF

echo "✅ .env.example criado"

# Criar diretório .github/workflows
mkdir -p .github/workflows

# Criar workflow do GitHub Actions
cat > .github/workflows/docker-build.yml << 'EOF'
name: Build and Push Docker Image

on:
  push:
    branches:
      - main
    tags:
      - 'v*.*.*'
  workflow_dispatch:

env:
  DOCKER_IMAGE: bartferr/wp-edidesk
  DOCKERFILE_PATH: ./Dockerfile

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.DOCKER_IMAGE }}
          tags: |
            type=ref,event=branch
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ${{ env.DOCKERFILE_PATH }}
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          platforms: linux/amd64,linux/arm64
EOF

echo "✅ GitHub Actions workflow criado"

# Criar README.md
cat > README.md << 'EOF'
# WordPress Custom - Edidesk

Imagem Docker customizada do WordPress com configurações de PHP otimizadas.

## Uso Rápido

```bash
docker pull bartferr/wp-edidesk:latest
docker-compose up -d
```

## Configurações

- Upload: 256MB
- Memory: 512MB
- Execution time: 300s

## Links

- Docker Hub: https://hub.docker.com/r/bartferr/wp-edidesk
- GitHub: https://github.com/Edidesk/wp-edidesk
EOF

echo "✅ README.md criado"

echo ""
echo "=========================================="
echo "✅ TODOS OS ARQUIVOS CRIADOS!"
echo "=========================================="
echo ""
echo "Arquivos criados:"
ls -la
echo ""
echo "Próximos passos:"
echo "1. git add ."
echo "2. git commit -m 'feat: configuração inicial'"
echo "3. git remote add origin https://github.com/Edidesk/wp-edidesk.git"
echo "4. git branch -M main"
echo "5. git push -u origin main"
