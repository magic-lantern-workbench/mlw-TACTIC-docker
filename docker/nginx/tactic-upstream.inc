upstream tactic_workers {
    least_conn;
    server tactic:8081 max_fails=3 fail_timeout=10s;
    server tactic:8082 max_fails=3 fail_timeout=10s;
    server tactic:8083 max_fails=3 fail_timeout=10s;
    keepalive 16;
}
