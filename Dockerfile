FROM cgr.dev/chainguard/nginx:latest

COPY index.html app.html public robots.txt /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf