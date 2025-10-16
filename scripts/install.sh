#!/bin/bash

# ========================================
# IoT Alarm CINCO - Installation Script
# ========================================
# Este script instala y configura todo lo necesario 
# para ejecutar el sistema en Raspberry Pi

set -e  # Exit on any error

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
    echo -e "${BLUE}  IoT Alarm CINCO - Installation${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
}

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on Raspberry Pi
check_raspberry_pi() {
    print_step "Verificando sistema..."
    if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        print_warning "No se detectó Raspberry Pi. Continuando de todos modos..."
    else
        print_step "✓ Raspberry Pi detectado"
    fi
}

# Update system
update_system() {
    print_step "Actualizando sistema..."
    sudo apt update
    sudo apt upgrade -y
}

# Install Node.js and npm
install_nodejs() {
    print_step "Instalando Node.js..."
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        print_step "✓ Node.js ya instalado: $NODE_VERSION"
    else
        # Install Node.js 18.x
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
        print_step "✓ Node.js instalado: $(node --version)"
    fi
}

# Install Docker and Docker Compose
install_docker() {
    print_step "Instalando Docker..."
    if command -v docker &> /dev/null; then
        print_step "✓ Docker ya instalado: $(docker --version)"
    else
        # Install Docker
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
        print_step "✓ Docker instalado"
    fi

    # Install Docker Compose
    if command -v docker-compose &> /dev/null; then
        print_step "✓ Docker Compose ya instalado: $(docker-compose --version)"
    else
        sudo apt-get install -y docker-compose
        print_step "✓ Docker Compose instalado"
    fi
}

# Install project dependencies
install_app_dependencies() {
    print_step "Instalando dependencias de la aplicación..."
    cd "$APP_DIR"
    npm install
    print_step "✓ Dependencias instaladas"
}

# Build React application
build_app() {
    print_step "Construyendo aplicación React..."
    cd "$APP_DIR"
    npm run build
    print_step "✓ Aplicación construida"
}

# Setup MQTT broker
setup_broker() {
    print_step "Configurando broker MQTT..."
    cd "$BROKER_DIR"
    
    # Set proper permissions
    sudo chown -R 1883:1883 data log
    sudo chmod -R 755 config data log
    
    print_step "✓ Broker MQTT configurado"
}

# Create systemd service
create_services() {
    print_step "Creando servicios del sistema..."
    
    # Service for React app
    sudo tee /etc/systemd/system/iot-alarm-web.service > /dev/null <<EOF
[Unit]
Description=IoT Alarm CINCO Web Application
After=network.target
Wants=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=$APP_DIR
Environment=PORT=5000
Environment=HOST=0.0.0.0
ExecStart=/usr/bin/npx serve -s build -l 5000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Service for MQTT broker (Docker Compose)
    sudo tee /etc/systemd/system/iot-alarm-mqtt.service > /dev/null <<EOF
[Unit]
Description=IoT Alarm CINCO MQTT Broker
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=pi
WorkingDirectory=$BROKER_DIR
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable services
    sudo systemctl daemon-reload
    sudo systemctl enable iot-alarm-web.service
    sudo systemctl enable iot-alarm-mqtt.service
    
    print_step "✓ Servicios creados y habilitados"
}

# Install serve globally for React app
install_serve() {
    print_step "Instalando serve para aplicación React..."
    sudo npm install -g serve
    print_step "✓ Serve instalado"
}

# Configure firewall
configure_firewall() {
    print_step "Configurando firewall..."
    sudo ufw allow 22/tcp    # SSH
    sudo ufw allow 80/tcp    # HTTP
    sudo ufw allow 5000/tcp  # React app
    sudo ufw allow 1883/tcp  # MQTT
    sudo ufw allow 8080/tcp  # MQTT WebSockets
    print_step "✓ Firewall configurado"
}

# Start services
start_services() {
    print_step "Iniciando servicios..."
    
    # Start MQTT broker
    sudo systemctl start iot-alarm-mqtt.service
    sleep 5
    
    # Start web application
    sudo systemctl start iot-alarm-web.service
    
    print_step "✓ Servicios iniciados"
}

# Show final information
show_completion() {
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Instalación Completada ✓${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "🌐 Aplicación web: ${BLUE}http://$(hostname -I | awk '{print $1}'):5000${NC}"
    echo -e "🌐 Aplicación web (local): ${BLUE}http://raspberrypi.local:5000${NC}"
    echo -e "📡 MQTT Broker: ${BLUE}$(hostname -I | awk '{print $1}'):1883${NC}"
    echo -e "🔌 MQTT WebSockets: ${BLUE}ws://$(hostname -I | awk '{print $1}'):8080${NC}"
    echo
    echo -e "${YELLOW}Comandos útiles:${NC}"
    echo -e "  • Ver logs web: ${BLUE}sudo journalctl -u iot-alarm-web -f${NC}"
    echo -e "  • Ver logs MQTT: ${BLUE}sudo journalctl -u iot-alarm-mqtt -f${NC}"
    echo -e "  • Reiniciar web: ${BLUE}sudo systemctl restart iot-alarm-web${NC}"
    echo -e "  • Reiniciar MQTT: ${BLUE}sudo systemctl restart iot-alarm-mqtt${NC}"
    echo -e "  • Estado servicios: ${BLUE}sudo systemctl status iot-alarm-*${NC}"
    echo
    echo -e "${GREEN}¡Sistema listo para usar! 🚀${NC}"
    echo
}

# Main installation process
main() {
    print_header
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_error "No ejecutar como root. Usar usuario regular con sudo."
        exit 1
    fi
    
    print_step "Iniciando instalación en: $PROJECT_DIR"
    
    check_raspberry_pi
    update_system
    install_nodejs
    install_docker
    install_serve
    install_app_dependencies
    build_app
    setup_broker
    create_services
    configure_firewall
    start_services
    show_completion
}

# Run main function
main "$@"
