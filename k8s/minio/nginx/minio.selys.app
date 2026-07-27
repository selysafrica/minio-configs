upstream minio_console {
    server 127.0.0.1:30023;
}

server {
    listen 80;
    server_name minio.selys.app;

    client_max_body_size 100m;
    proxy_buffering off;

    ignore_invalid_headers off;

    location / {
        proxy_pass https://minio_console;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-NginX-Proxy true;

        # WebSocket support for console
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_connect_timeout 300;
        proxy_read_timeout 300;
        proxy_send_timeout 300;
    }
}
