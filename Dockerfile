# Usamos Nginx para servir la web de forma ligera
FROM nginx:alpine

# Copiamos los archivos que GitHub Actions compilará por nosotros
COPY build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]