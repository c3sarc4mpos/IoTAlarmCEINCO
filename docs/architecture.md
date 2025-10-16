# Arquitectura del Sistema IoT Alarm CINCO

## 📋 Resumen del Sistema

El sistema IoT Alarm CINCO es una solución completa de control de alarmas que conecta 4 dispositivos NodeMCU (ESP8266) con una aplicación web central alojada en Raspberry Pi, utilizando MQTT como protocolo de comunicación.

## 🏗️ Arquitectura General

```
┌─────────────────────────────────────────────────────────────────┐
│                        RED LOCAL (LAN)                          │
│                                                                 │
│  ┌─────────────────┐    ┌──────────────────┐    ┌─────────────┐ │
│  │  Raspberry Pi   │◄──►│  Router/Switch   │◄──►│   Devices   │ │
│  │                 │    │                  │    │ (Móvil/PC)  │ │
│  │ • Web App       │    │                  │    │             │ │
│  │ • MQTT Broker   │    │                  │    │             │ │
│  └─────────────────┘    └──────────────────┘    └─────────────┘ │
│           │                       │                              │
│           │                       │                              │
│  ┌────────▼─────┐        ┌────────▼─────┐                        │
│  │  NodeMCU #1  │        │  NodeMCU #2  │                        │
│  │  Alarma 1    │        │  Alarma 2    │                        │
│  └──────────────┘        └──────────────┘                        │
│           │                       │                              │
│  ┌────────▼─────┐        ┌────────▼─────┐                        │
│  │  NodeMCU #3  │        │  NodeMCU #4  │                        │
│  │  Alarma 3    │        │  Alarma 4    │                        │
│  └──────────────┘        └──────────────┘                        │
└─────────────────────────────────────────────────────────────────┘
```

## 🔧 Componentes del Sistema

### 1. Hardware

#### Raspberry Pi 3 (Servidor Central)
- **OS**: Raspbian/Raspberry Pi OS
- **Servicios**:
  - Aplicación Web React (Puerto 5000)
  - Broker MQTT Mosquitto (Puerto 1883 + 8080 WebSocket)
- **Almacenamiento**: Logs, configuración, datos persistentes

#### NodeMCU ESP8266 (x4 unidades)
- **Microcontrolador**: ESP8266
- **Conectividad**: WiFi 2.4GHz
- **Hardware Conectado**:
  - LED integrado (Pin D0/GPIO16)
  - Relé (Pin D5/GPIO14)
  - LED externo (Pin D4/GPIO2)
  - Pulsador físico (Pin D1/GPIO5)

### 2. Software

#### Aplicación Web (Frontend)
- **Framework**: React 18
- **Librería MQTT**: mqtt.js v5.3.0
- **Interfaz**: Responsive, mobile-first
- **Tema**: Verde dominante con contrastes de alarma
- **Funcionalidades**:
  - 4 interruptores individuales
  - Control maestro (todas las alarmas)
  - Monitoreo en tiempo real
  - Configuración de broker MQTT

#### Broker MQTT
- **Software**: Eclipse Mosquitto 2.0
- **Puertos**:
  - 1883: MQTT estándar
  - 8080: WebSocket para navegadores
- **Configuración**: Sin autenticación (LAN local)

## 📡 Protocolo de Comunicación MQTT

### Topics de Control (Publicación desde Web App)
```
sirena/1    → Control de NodeMCU #1
sirena/2    → Control de NodeMCU #2  
sirena/3    → Control de NodeMCU #3
sirena/4    → Control de NodeMCU #4
SENA_led    → Control global (compatibilidad)
```

### Topics de Estado (Suscripción en Web App)
```
estado/sirena1    → Estado de NodeMCU #1
estado/sirena2    → Estado de NodeMCU #2
estado/sirena3    → Estado de NodeMCU #3
estado/sirena4    → Estado de NodeMCU #4
estado/sirenas    → Estado global consolidado
```

### Topics de Botones Físicos
```
boton/1    → Pulsador físico NodeMCU #1
boton/2    → Pulsador físico NodeMCU #2
boton/3    → Pulsador físico NodeMCU #3
boton/4    → Pulsador físico NodeMCU #4
```

### Mensajes MQTT

#### Comandos de Control
```json
Tema: "sirena/N"
Payload: "on"  | "off"
QoS: 1
Retained: false
```

#### Mensajes de Estado
```json
Tema: "estado/sirenaN"
Payload: "on"  | "off"
QoS: 0
Retained: true

Tema: "estado/sirenas"
Payload: "sirena N on" | "sirena N off"
QoS: 0
Retained: false
```

#### Eventos de Botones
```json
Tema: "boton/N"
Payload: "on"
QoS: 0
Retained: false
```

## 🔄 Flujo de Operación

### Activación de Alarma desde Web App

1. **Usuario** hace clic en switch de alarma N
2. **React App** publica mensaje `"on"` en topic `sirena/N`
3. **Broker MQTT** distribuye mensaje a suscriptores
4. **NodeMCU N** recibe mensaje y activa:
   - LED integrado (HIGH)
   - Relé (HIGH)
   - LED externo (HIGH)
5. **NodeMCU N** confirma estado publicando `"on"` en `estado/sirenaN`
6. **React App** recibe confirmación y actualiza UI
7. **NodeMCU N** auto-desactiva después de 60 segundos

### Activación desde Botón Físico

1. **Usuario** presiona botón físico en NodeMCU N
2. **NodeMCU N** detecta pulsación (con debounce)
3. **NodeMCU N** publica `"on"` en `boton/N`
4. **NodeMCU N** activa sirena internamente
5. **NodeMCU N** publica estado `"on"` en `estado/sirenaN`
6. **React App** recibe estado y actualiza UI

## 🛠️ Configuración de Red

### Direccionamiento IP
```
Router LAN:          192.168.1.1
Raspberry Pi:        192.168.1.100 (estática recomendada)
NodeMCU #1:          192.168.1.101 (DHCP)
NodeMCU #2:          192.168.1.102 (DHCP)
NodeMCU #3:          192.168.1.103 (DHCP)
NodeMCU #4:          192.168.1.104 (DHCP)
```

### Puertos de Red
```
TCP 22    → SSH (administración)
TCP 80    → HTTP (redirección opcional)
TCP 5000  → Web App React
TCP 1883  → MQTT Protocol
TCP 8080  → MQTT WebSocket
```

### Acceso mDNS
```
http://raspberrypi.local:5000    → Web App
ws://raspberrypi.local:8080      → MQTT WebSocket
```

## 🔐 Seguridad

### Nivel de Red
- **Firewall**: ufw configurado con puertos específicos
- **Red Aislada**: Sistema funciona solo en LAN local
- **Sin Internet**: No requiere conexión externa

### Nivel MQTT
- **Autenticación**: Deshabilitada (red local confiable)
- **TLS/SSL**: No implementado (tráfico local)
- **ACL**: No configurado (acceso abierto en LAN)

### Nivel Aplicación
- **Validación**: Mensajes MQTT validados
- **Estado Optimista**: Confirmación desde dispositivos
- **Timeout**: Auto-desactivación de alarmas (60s)

## 📊 Monitoreo y Logs

### Logs del Sistema
```bash
# Web App
sudo journalctl -u iot-alarm-web.service -f

# MQTT Broker  
sudo journalctl -u iot-alarm-mqtt.service -f

# Docker MQTT
docker logs iot-alarm-mosquitto -f
```

### Métricas Disponibles
- Estado de conexión MQTT
- Tiempo de última actualización por alarma
- Número de alarmas activas
- Mensajes MQTT procesados

## 🚀 Escalabilidad

### Agregar Nuevas Alarmas
1. Configurar NodeMCU con número único (5, 6, etc.)
2. Actualizar topics en código ESP8266
3. Modificar Web App para incluir nuevos switches
4. Actualizar configuración MQTT si es necesario

### Funcionalidades Adicionales
- **Base de Datos**: SQLite para historial de eventos
- **Notificaciones**: Push notifications o email
- **API REST**: Endpoints para integración externa
- **Dashboard Avanzado**: Gráficos y estadísticas
- **Autenticación**: Login de usuarios
- **HTTPS/WSS**: Certificados SSL para seguridad

## ⚡ Rendimiento

### Latencia Típica
- **Web App → MQTT**: < 50ms
- **MQTT → NodeMCU**: < 100ms
- **NodeMCU → Activación**: < 200ms
- **Total**: < 350ms para activación completa

### Recursos del Sistema
- **Raspberry Pi CPU**: ~5-10% en operación normal
- **RAM**: ~150MB para todos los servicios
- **Almacenamiento**: ~500MB completo
- **Red**: < 1Kbps tráfico MQTT normal

### Límites del Sistema
- **NodeMCUs Concurrentes**: 50+ (limitado por WiFi router)
- **Conexiones WebSocket**: 100 (configuración Mosquitto)
- **Mensajes/Segundo**: 1000+ (Raspberry Pi 3)

## 🧪 Testing y Validación

### Tests Automatizados
- Conexión MQTT (publish/subscribe)
- Estado de servicios systemd
- Conectividad de red
- Respuesta HTTP de Web App

### Tests Manuales
- Activación/desactivación por alarma
- Control maestro
- Botones físicos en NodeMCUs
- Reconexión automática
- Auto-desactivación (60s)

Este documento proporciona una visión completa de la arquitectura del sistema IoT Alarm CINCO, facilitando el mantenimiento, troubleshooting y futuras mejoras.
