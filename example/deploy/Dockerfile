# Usamos una imagen muy ligera de Nginx basada en Alpine para un cold start mínimo
FROM nginx:alpine

# Copiamos nuestra configuración personalizada de Nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copiamos los archivos de compilación de Flutter al directorio que sirve Nginx
COPY build/web/ /usr/share/nginx/html/

# Exponemos el puerto 8080 que es el estándar esperado por Cloud Run
EXPOSE 8080

# Arrancamos Nginx
CMD ["nginx", "-g", "daemon off;"]