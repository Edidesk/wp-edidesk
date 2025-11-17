# Usar a imagem oficial do WordPress como base
FROM wordpress:6.7-php8.2-apache

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