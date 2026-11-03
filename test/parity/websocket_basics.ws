CONNECT ws://localhost:8080/chat
< welcome
ON hello
< hi, Kim
< {"kind":"news","text":"rain"}

CONNECT ws://localhost:8080/down
FAILS connection refused
