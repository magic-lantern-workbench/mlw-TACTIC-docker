client_max_body_size 0;   # check-ins can be large; TACTIC enforces its own limits
proxy_read_timeout 600s;
proxy_send_timeout 600s;

gzip on;
gzip_types text/plain text/css text/xml application/xml application/javascript application/x-javascript application/json;

location /assets/ {
    alias /opt/tactic/tactic_data/assets/;
    expires 1h;
}
location /context/ {
    alias /opt/tactic/tactic/src/context/;
    expires 1h;
}
location / {
    proxy_pass http://tactic_workers;
    proxy_http_version 1.1;
    proxy_set_header Host $http_host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Connection "";
}
