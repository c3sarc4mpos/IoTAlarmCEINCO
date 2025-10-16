import React, { useState, useEffect } from 'react';
import AlarmSwitch from './components/AlarmSwitch';
import mqttService from './services/mqttService';
import './App.css';

function App() {
  const [alarms, setAlarms] = useState({
    1: { isActive: false, lastUpdate: null },
    2: { isActive: false, lastUpdate: null },
    3: { isActive: false, lastUpdate: null },
    4: { isActive: false, lastUpdate: null }
  });
  
  const [isConnected, setIsConnected] = useState(false);
  const [brokerUrl, setBrokerUrl] = useState('ws://192.168.1.100:8080');
  const [connectionMessage, setConnectionMessage] = useState('');

  useEffect(() => {
    // Configurar listeners para eventos MQTT
    const handleMqttEvent = (event, data) => {
      switch (event) {
        case 'connected':
          setIsConnected(data);
          setConnectionMessage(data ? '✅ Conectado al broker MQTT' : '❌ Desconectado del broker');
          break;
        case 'error':
          setIsConnected(false);
          setConnectionMessage(`❌ Error de conexión: ${data.message || data}`);
          console.error('MQTT Error:', data);
          break;
        case 'message':
          handleMqttMessage(data);
          break;
        default:
          break;
      }
    };

    mqttService.addListener(handleMqttEvent);

    // Conectar automáticamente al montar el componente
    connectToMqtt();

    // Cleanup al desmontar
    return () => {
      mqttService.removeListener(handleMqttEvent);
      mqttService.disconnect();
    };
  }, []);

  const handleMqttMessage = ({ topic, message }) => {
    console.log('Procesando mensaje MQTT:', { topic, message });
    
    // Parsear topic para obtener el ID de la alarma
    if (topic.startsWith('estado/sirena')) {
      const alarmId = topic.replace('estado/sirena', '');
      if (alarmId >= 1 && alarmId <= 4) {
        const isActive = message.toLowerCase() === 'on';
        updateAlarmState(parseInt(alarmId), isActive);
      }
    }
    
    // Manejar topic global (para compatibilidad)
    if (topic === 'estado/sirenas') {
      const match = message.match(/sirena (\d+) (on|off)/);
      if (match) {
        const alarmId = parseInt(match[1]);
        const isActive = match[2] === 'on';
        updateAlarmState(alarmId, isActive);
      }
    }
  };

  const updateAlarmState = (alarmId, isActive) => {
    setAlarms(prevAlarms => ({
      ...prevAlarms,
      [alarmId]: {
        ...prevAlarms[alarmId],
        isActive: isActive,
        lastUpdate: new Date()
      }
    }));
  };

  const connectToMqtt = () => {
    setConnectionMessage('🔄 Conectando al broker MQTT...');
    mqttService.connect(brokerUrl);
  };

  const handleAlarmToggle = (alarmId, newState) => {
    console.log(`Controlando alarma ${alarmId}: ${newState ? 'ON' : 'OFF'}`);
    
    if (!isConnected) {
      alert('❌ No hay conexión con el broker MQTT');
      return;
    }

    // Enviar comando MQTT
    mqttService.controlAlarm(alarmId, newState);
    
    // Actualización optimista del estado local
    updateAlarmState(alarmId, newState);
  };

  const handleMasterControl = (state) => {
    if (!isConnected) {
      alert('❌ No hay conexión con el broker MQTT');
      return;
    }

    console.log(`Control maestro: ${state ? 'ACTIVAR' : 'DESACTIVAR'} todas las alarmas`);
    mqttService.controlAllAlarms(state);
    
    // Actualización optimista del estado local para todas las alarmas
    const newAlarms = { ...alarms };
    for (let i = 1; i <= 4; i++) {
      newAlarms[i] = {
        ...newAlarms[i],
        isActive: state,
        lastUpdate: new Date()
      };
    }
    setAlarms(newAlarms);
  };

  const getActiveAlarmsCount = () => {
    return Object.values(alarms).filter(alarm => alarm.isActive).length;
  };

  const handleBrokerUrlChange = (e) => {
    setBrokerUrl(e.target.value);
  };

  const handleReconnect = () => {
    mqttService.disconnect();
    setTimeout(() => connectToMqtt(), 1000);
  };

  return (
    <div className="app">
      <div className="app-header">
        <h1>🚨 Sistema IoT Alarm CINCO</h1>
        <div className="connection-status">
          <div className={`status-indicator ${isConnected ? 'connected' : 'disconnected'}`}>
            <div className="status-dot"></div>
            <span>{connectionMessage}</span>
          </div>
        </div>
      </div>

      <div className="broker-config">
        <div className="config-group">
          <label htmlFor="brokerUrl">Broker MQTT:</label>
          <input
            id="brokerUrl"
            type="text"
            value={brokerUrl}
            onChange={handleBrokerUrlChange}
            placeholder="ws://192.168.1.100:8080"
            disabled={isConnected}
          />
          <button 
            onClick={handleReconnect}
            className="reconnect-btn"
            disabled={isConnected}
          >
            {isConnected ? '✅ Conectado' : '🔄 Reconectar'}
          </button>
        </div>
      </div>

      <div className="master-controls">
        <div className="master-info">
          <h3>Control Maestro</h3>
          <p>Alarmas activas: <span className="active-count">{getActiveAlarmsCount()}</span>/4</p>
        </div>
        <div className="master-buttons">
          <button 
            className="master-btn activate-all"
            onClick={() => handleMasterControl(true)}
            disabled={!isConnected}
          >
            🚨 ACTIVAR TODAS
          </button>
          <button 
            className="master-btn deactivate-all"
            onClick={() => handleMasterControl(false)}
            disabled={!isConnected}
          >
            ✅ DESACTIVAR TODAS
          </button>
        </div>
      </div>

      <div className="alarms-grid">
        {[1, 2, 3, 4].map(alarmId => (
          <AlarmSwitch
            key={alarmId}
            alarmId={alarmId}
            isActive={alarms[alarmId].isActive}
            isConnected={isConnected}
            onToggle={handleAlarmToggle}
            lastUpdate={alarms[alarmId].lastUpdate}
          />
        ))}
      </div>

      <div className="app-footer">
        <div className="footer-info">
          <p>🏠 Sistema IoT para control de alarmas locales</p>
          <p>📡 MQTT Topics: sirena/[1-4] (control) | estado/sirena[1-4] (estado)</p>
          <p>🔧 Desarrollado para Raspberry Pi con NodeMCU ESP8266</p>
        </div>
      </div>
    </div>
  );
}

export default App;
