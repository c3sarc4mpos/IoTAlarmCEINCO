#!/bin/bash

# ========================================
# IoT Alarm CINCO - Management Script
# ========================================
# Script para gestionar el sistema después de la instalación

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script info
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_DIR="$PROJECT_DIR/app"
BROKER_DIR="$PROJECT_DIR/broker"

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  IoT Alarm CINCO - Management${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_step() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show system status
status() {
    print_header
    echo -e "\n${GREEN}Estado del Sistema:${NC}\n"
    
    # Check services
    echo -e "${BLUE}Servicios:${NC}"
    if systemctl is-active --quiet iot-alarm-web.service; then
        echo -e "  • Web App: ${GREEN}✓ Activo${NC}"
    else
        echo -e "  • Web App: ${RED}✗ Inactivo${NC}"
    fi
    
    if systemctl is-active --quiet iot-alarm-mqtt.service; then
        echo -e "  • MQTT Broker: ${GREEN}✓ Activo${NC}"
    else
        echo -e "  • MQTT Broker: ${RED}✗ Inactivo${NC}"
    fi
    
    # Check ports
    echo -e "\n${BLUE}Puertos:${NC}"
    if netstat -tln | grep -q ":5000"; then
        echo -e "  • Puerto 5000 (Web): ${GREEN}✓ Abierto${NC}"
    else
        echo -e "  • Puerto 5000 (Web): ${RED}✗ Cerrado${NC}"
    fi
    
    if netstat -tln | grep -q ":1883"; then
        echo -e "  • Puerto 1883 (MQTT): ${GREEN}✓ Abierto${NC}"
    else
        echo -e "  • Puerto 1883 (MQTT): ${RED}✗ Cerrado${NC}"
    fi
    
    if netstat -tln | grep -q ":8080"; then
        echo -e "  • Puerto 8080 (WebSocket): ${GREEN}✓ Abierto${NC}"
    else
        echo -e "  • Puerto 8080 (WebSocket): ${RED}✗ Cerrado${NC}"
    fi
    
    # Show URLs
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    echo -e "\n${BLUE}URLs de Acceso:${NC}"
    echo -e "  • Web App: ${GREEN}http://$LOCAL_IP:5000${NC}"
    echo -e "  • Web App (mDNS): ${GREEN}http://raspberrypi.local:5000${NC}"
    echo -e "  • MQTT Broker: ${GREEN}$LOCAL_IP:1883${NC}"
    echo -e "  • MQTT WebSocket: ${GREEN}ws://$LOCAL_IP:8080${NC}"
    echo
}

# Start all services
start() {
    print_step "Iniciando servicios..."
    sudo systemctl start iot-alarm-mqtt.service
    sleep 3
    sudo systemctl start iot-alarm-web.service
    print_step "✓ Servicios iniciados"
}

# Stop all services
stop() {
    print_step "Deteniendo servicios..."
    sudo systemctl stop iot-alarm-web.service
    sudo systemctl stop iot-alarm-mqtt.service
    print_step "✓ Servicios detenidos"
}

# Restart all services
restart() {
    print_step "Reiniciando servicios..."
    stop
    sleep 2
    start
    print_step "✓ Servicios reiniciados"
}

# Update application
update() {
    print_step "Actualizando aplicación..."
    
    # Stop services
    stop
    
    # Update app dependencies and rebuild
    cd "$APP_DIR"
    npm install
    npm run build
    
    # Restart services
    start
    
    print_step "✓ Aplicación actualizada"
}

# Show logs
logs() {
    case $2 in
        web)
            print_step "Logs de la aplicación web:"
            sudo journalctl -u iot-alarm-web.service -f
            ;;
        mqtt)
            print_step "Logs del broker MQTT:"
            sudo journalctl -u iot-alarm-mqtt.service -f
            ;;
        all|*)
            print_step "Logs de todos los servicios:"
            sudo journalctl -u iot-alarm-web.service -u iot-alarm-mqtt.service -f
            ;;
    esac
}

# Test MQTT connection
test_mqtt() {
    print_step "Probando conexión MQTT..."
    
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    
    # Test publish
    if mosquitto_pub -h "$LOCAL_IP" -t "test/connection" -m "test" 2>/dev/null; then
        print_step "✓ MQTT Publish: OK"
    else
        print_error "✗ MQTT Publish: Error"
    fi
    
    # Test subscribe (timeout after 2 seconds)
    if timeout 2 mosquitto_sub -h "$LOCAL_IP" -t "test/connection" -C 1 >/dev/null 2>&1; then
        print_step "✓ MQTT Subscribe: OK"
    else
        print_error "✗ MQTT Subscribe: Error"
    fi
}

# Backup configuration
backup() {
    BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$HOME/iot_alarm_backup_$BACKUP_DATE.tar.gz"
    
    print_step "Creando backup en: $BACKUP_FILE"
    
    tar -czf "$BACKUP_FILE" -C "$PROJECT_DIR" \
        app/build \
        app/package.json \
        app/package-lock.json \
        broker/config \
        broker/data \
        esp8266_code \
        docs \
        README.md
    
    print_step "✓ Backup creado: $BACKUP_FILE"
}

# Show help
show_help() {
    print_header
    echo -e "\n${GREEN}Uso:${NC} ./manage.sh [comando]\n"
    echo -e "${BLUE}Comandos disponibles:${NC}"
    echo -e "  ${GREEN}status${NC}     - Mostrar estado del sistema"
    echo -e "  ${GREEN}start${NC}      - Iniciar todos los servicios"
    echo -e "  ${GREEN}stop${NC}       - Detener todos los servicios"
    echo -e "  ${GREEN}restart${NC}    - Reiniciar todos los servicios"
    echo -e "  ${GREEN}update${NC}     - Actualizar la aplicación"
    echo -e "  ${GREEN}logs [tipo]${NC} - Ver logs (web|mqtt|all)"
    echo -e "  ${GREEN}test${NC}       - Probar conexión MQTT"
    echo -e "  ${GREEN}backup${NC}     - Crear backup de configuración"
    echo -e "  ${GREEN}help${NC}       - Mostrar esta ayuda"
    echo
    echo -e "${YELLOW}Ejemplos:${NC}"
    echo -e "  ./manage.sh status"
    echo -e "  ./manage.sh logs web"
    echo -e "  ./manage.sh restart"
    echo
}

# Main function
case $1 in
    status)
        status
        ;;
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    update)
        update
        ;;
    logs)
        logs "$@"
        ;;
    test)
        test_mqtt
        ;;
    backup)
        backup
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Comando no reconocido: $1"
        echo
        show_help
        exit 1
        ;;
esac
