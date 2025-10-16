import mqtt from 'mqtt';

class MQTTService {
  constructor() {
    this.client = null;
    this.isConnected = false;
    this.listeners = [];
    this.retryAttempts = 0;
    this.maxRetries = 5;
  }

  // Configuración del broker MQTT
  connect(brokerUrl = 'ws://raspberrypi.local:8080') {
    try {
      console.log('Conectando al broker MQTT:', brokerUrl);
      
      // Opciones de conexión
      const options = {
        connectTimeout: 4000,
        clientId: `iot_alarm_web_${Math.random().toString(16).substr(2, 8)}`,
        username: '', // Añadir si se requiere autenticación
        password: '', // Añadir si se requiere autenticación
        clean: true,
        reconnectPeriod: 1000,
        keepalive: 60
      };

      this.client = mqtt.connect(brokerUrl, options);

      this.client.on('connect', () => {
        console.log('✅ Conectado al broker MQTT');
        this.isConnected = true;
        this.retryAttempts = 0;
        this.subscribeToAlarmTopics();
        this.notifyListeners('connected', true);
      });

      this.client.on('error', (error) => {
        console.error('❌ Error de conexión MQTT:', error);
        this.isConnected = false;
        this.notifyListeners('error', error);
      });

      this.client.on('offline', () => {
        console.log('📴 Cliente MQTT desconectado');
        this.isConnected = false;
        this.notifyListeners('connected', false);
      });

      this.client.on('reconnect', () => {
        console.log('🔄 Reintentando conexión MQTT...');
        this.retryAttempts++;
        if (this.retryAttempts > this.maxRetries) {
          console.log('❌ Máximo número de reintentos alcanzado');
          this.client.end();
        }
      });

      this.client.on('message', (topic, message) => {
        const messageStr = message.toString();
        console.log(`📨 Mensaje recibido - Topic: ${topic}, Mensaje: ${messageStr}`);
        this.notifyListeners('message', { topic, message: messageStr });
      });

    } catch (error) {
      console.error('❌ Error al conectar MQTT:', error);
      this.notifyListeners('error', error);
    }
  }

  // Suscribirse a los topics de las alarmas
  subscribeToAlarmTopics() {
    if (!this.client || !this.isConnected) return;

    const topics = [
      'estado/sirena1',
      'estado/sirena2', 
      'estado/sirena3',
      'estado/sirena4',
      'estado/sirenas' // Topic global para monitoreo
    ];

    topics.forEach(topic => {
      this.client.subscribe(topic, (error) => {
        if (error) {
          console.error(`❌ Error al suscribirse a ${topic}:`, error);
        } else {
          console.log(`✅ Suscrito a: ${topic}`);
        }
      });
    });
  }

  // Controlar alarma específica
  controlAlarm(alarmId, state) {
    if (!this.client || !this.isConnected) {
      console.error('❌ Cliente MQTT no conectado');
      return false;
    }

    const topic = `sirena/${alarmId}`;
    const message = state ? 'on' : 'off';

    this.client.publish(topic, message, { qos: 1 }, (error) => {
      if (error) {
        console.error(`❌ Error al enviar comando a ${topic}:`, error);
      } else {
        console.log(`✅ Comando enviado - Topic: ${topic}, Mensaje: ${message}`);
      }
    });

    return true;
  }

  // Controlar todas las alarmas
  controlAllAlarms(state) {
    for (let i = 1; i <= 4; i++) {
      this.controlAlarm(i, state);
    }
  }

  // Registrar listener para eventos
  addListener(callback) {
    this.listeners.push(callback);
  }

  // Remover listener
  removeListener(callback) {
    this.listeners = this.listeners.filter(listener => listener !== callback);
  }

  // Notificar a todos los listeners
  notifyListeners(event, data) {
    this.listeners.forEach(listener => {
      try {
        listener(event, data);
      } catch (error) {
        console.error('❌ Error en listener:', error);
      }
    });
  }

  // Desconectar cliente
  disconnect() {
    if (this.client) {
      this.client.end();
      this.isConnected = false;
      console.log('🔌 Cliente MQTT desconectado');
    }
  }

  // Obtener estado de conexión
  getConnectionStatus() {
    return this.isConnected;
  }
}

// Exportar instancia singleton
export default new MQTTService();
