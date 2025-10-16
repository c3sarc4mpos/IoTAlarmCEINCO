import React from 'react';
import './AlarmSwitch.css';

const AlarmSwitch = ({ 
  alarmId, 
  isActive, 
  isConnected, 
  onToggle,
  lastUpdate 
}) => {
  const handleClick = () => {
    if (isConnected) {
      onToggle(alarmId, !isActive);
    }
  };

  const formatLastUpdate = (timestamp) => {
    if (!timestamp) return 'Sin datos';
    const date = new Date(timestamp);
    return date.toLocaleTimeString('es-ES', { 
      hour: '2-digit', 
      minute: '2-digit',
      second: '2-digit'
    });
  };

  return (
    <div className={`alarm-switch ${isActive ? 'active' : 'inactive'} ${!isConnected ? 'disconnected' : ''}`}>
      <div className="alarm-header">
        <h3>Alarma {alarmId}</h3>
        <div className="status-indicator">
          <div className={`status-dot ${isConnected ? 'connected' : 'disconnected'}`}></div>
          <span className="status-text">
            {isConnected ? 'Conectada' : 'Desconectada'}
          </span>
        </div>
      </div>

      <div className="switch-container" onClick={handleClick}>
        <div className={`switch ${isActive ? 'switch-on' : 'switch-off'} ${!isConnected ? 'switch-disabled' : ''}`}>
          <div className="switch-handle"></div>
        </div>
        <span className={`switch-label ${isActive ? 'label-on' : 'label-off'}`}>
          {isActive ? 'ACTIVADA' : 'DESACTIVADA'}
        </span>
      </div>

      <div className="alarm-info">
        <div className="info-item">
          <span className="info-label">Estado:</span>
          <span className={`info-value ${isActive ? 'value-active' : 'value-inactive'}`}>
            {isActive ? '🚨 ACTIVA' : '✅ INACTIVA'}
          </span>
        </div>
        <div className="info-item">
          <span className="info-label">Última actualización:</span>
          <span className="info-value">{formatLastUpdate(lastUpdate)}</span>
        </div>
      </div>

      {isActive && (
        <div className="alarm-warning">
          <div className="warning-pulse"></div>
          <span>¡ALARMA ACTIVADA!</span>
        </div>
      )}
    </div>
  );
};

export default AlarmSwitch;
