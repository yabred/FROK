#!/bin/bash

# Wrapper script for playing sounds via audio daemon

SOCKET_PATH="/tmp/frok.sock"
COMMAND="${1:-}"

# Если команда "-stop", оставляем как есть для остановки воспроизведения
# Иначе передаём имя файла как есть (демон сам разберётся)
# Если аргумент не передан, передаём пустую строку (демон воспроизведёт дефолтный звук)

# Try to send command via Unix socket
if [ -S "$SOCKET_PATH" ]; then
    # Try using nc with Unix socket support
    if echo "$COMMAND" | nc -U "$SOCKET_PATH" 2>/dev/null; then
        exit 0
    fi
    
    # Fallback: try using Node.js if nc doesn't work
    if command -v node &> /dev/null; then
        node -e "
            const net = require('net');
            const client = net.createConnection('$SOCKET_PATH', () => {
                client.write('$COMMAND');
                client.end();
            });
            client.on('error', () => process.exit(1));
        " 2>/dev/null && exit 0
    fi
fi
