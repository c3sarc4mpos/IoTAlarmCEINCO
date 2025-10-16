#include <ESP8266WiFi.h>
#include <PubSubClient.h>

const char* ssid = "senaAPRENDICES";
const char* password = "senaApr3nd1z2025**";
const char* mqttServer = "test.mosquitto.org";
int port = 1883;

WiFiClient espClient;
PubSubClient client(espClient);

const int ledPin = 16;     // LED integrado NodeMCU (D0)
const int relePin = 14;    // Rele (D5)
const int onPin = 2;       // LED externo (opcional) (D4)
const int buttonPin = 5;   // Pulsador en D1 (GPIO5)

// Configuración individual para cada NodeMCU
const int nodeNumber = 3;  // CAMBIAR ESTE VALOR (1, 2, 3, 4) PARA CADA NODEMCU
char topicSirena[20];
char topicButton[20];
char topicEstado[20];  // Topic individual para el estado

unsigned long lastMsgTime = 0;
bool sirenaActive = false;
bool buttonState = HIGH;
bool lastButtonState = HIGH;
unsigned long debounceTime = 0;
const unsigned long debounceDelay = 50;
const unsigned long sirenaDuration = 60000;  // 60 segundos = 60000 ms

char clientId[50];

void setup() {
  Serial.begin(115200);
  randomSeed(analogRead(0));
  
  // Configurar topics según el número del nodo
  sprintf(topicSirena, "sirena/%d", nodeNumber);
  sprintf(topicButton, "boton/%d", nodeNumber);
  sprintf(topicEstado, "estado/sirena%d", nodeNumber);  // Topic individual para estado

  pinMode(ledPin, OUTPUT);
  pinMode(relePin, OUTPUT);
  pinMode(onPin, OUTPUT);
  pinMode(buttonPin, INPUT_PULLUP);

  // Inicializar todos los pines en estado APAGADO
  digitalWrite(ledPin, LOW);
  digitalWrite(relePin, LOW);
  digitalWrite(onPin, LOW);

  wifiConnect();

  Serial.println("WiFi conectado - IP: ");
  Serial.println(WiFi.localIP());

  client.setServer(mqttServer, port);
  client.setCallback(callback);

  // Mantener LED apagado después de la conexión
  digitalWrite(ledPin, LOW);
}

void wifiConnect() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
    // Parpadear LED durante conexión
    digitalWrite(ledPin, !digitalRead(ledPin));
  }
}

void mqttReconnect() {
  while (!client.connected()) {
    Serial.print("Intentando conexión MQTT...");
    long r = random(1000);
    sprintf(clientId, "clientId-%ld", r);
    if (client.connect(clientId)) {
      Serial.println(" conectado");
      // Suscribirse a ambos topics: el individual y el global para compatibilidad
      client.subscribe(topicSirena);    // Topic individual (ej: sirena/1)
      client.subscribe("SENA_led");     // Topic global (para compatibilidad)
      
      // Publicar estado inicial al conectarse
      client.publish(topicEstado, "off");
    } else {
      Serial.print("falló, rc=");
      Serial.print(client.state());
      Serial.println(" intentando en 5 segundos");
      delay(5000);
    }
  }
}

void callback(char* topic, byte* message, unsigned int length) {
  Serial.print("Mensaje recibido en el tema: ");
  Serial.print(topic);
  Serial.print(". Mensaje: ");
  
  String stMessage;
  for (int i = 0; i < length; i++) {
    stMessage += (char)message[i];
  }
  Serial.println(stMessage);

  // Manejar ambos topics
  if (String(topic) == topicSirena || String(topic) == "SENA_led") {
    if (stMessage == "on") {
      activateSirena();
    } else if (stMessage == "off") {
      deactivateSirena();
    }
  }
}

void activateSirena() {
  if (sirenaActive) return;  // Si ya está activa, no hacer nada
  
  Serial.println("Activando sirena");
  digitalWrite(relePin, HIGH);
  digitalWrite(onPin, HIGH);
  digitalWrite(ledPin, HIGH);
  sirenaActive = true;
  lastMsgTime = millis();
  
  // Publicar mensajes de confirmación
  char msg[50];
  sprintf(msg, "sirena %d on", nodeNumber);
  client.publish("estado/sirenas", msg);
  client.publish(topicEstado, "on");  // Publicar en topic individual
}

void deactivateSirena() {
  if (!sirenaActive) return;  // Si ya está desactivada, no hacer nada
  
  Serial.println("Desactivando sirena");
  digitalWrite(relePin, LOW);
  digitalWrite(onPin, LOW);
  digitalWrite(ledPin, LOW);
  sirenaActive = false;
  
  // Publicar mensajes de confirmación
  char msg[50];
  sprintf(msg, "sirena %d off", nodeNumber);
  client.publish("estado/sirenas", msg);
  client.publish(topicEstado, "off");  // Publicar en topic individual
}

void checkButton() {
  int reading = digitalRead(buttonPin);
  
  if (reading != lastButtonState) {
    debounceTime = millis();
  }
  
  if ((millis() - debounceTime) > debounceDelay) {
    if (reading != buttonState) {
      buttonState = reading;
      
      if (buttonState == LOW) {
        Serial.println("Boton presionado");
        client.publish(topicButton, "on");
        activateSirena();
      }
    }
  }
  
  lastButtonState = reading;
}

void loop() {
  if (!client.connected()) {
    mqttReconnect();
  }
  client.loop();

  checkButton();

  // Apagar automáticamente después de 60 segundos
  if (sirenaActive && (millis() - lastMsgTime > sirenaDuration)) {
    deactivateSirena();
  }
}