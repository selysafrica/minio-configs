upstream minio_api {
    server 127.0.0.1:30021;
}

server {
    listen 80;
    server_name s3.selys.app;

    client_max_body_size 1000m;
    proxy_buffering off;
    proxy_request_buffering off;

    location / {
        proxy_pass http://minio_api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 300;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        chunked_transfer_encoding off;
    }
}
