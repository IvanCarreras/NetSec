# 🚀 MiniSOC - Quick Start

## 5 minutos para tener el Stack funcionando

### Opción 1: En tu máquina actual (ya con Docker)

```bash
# 1. Crear estructura
mkdir -p ~/minisoc/{logstash/conf.d,filebeat,suricata/rules,data}
cd ~/minisoc

# 2. Copiar archivos de configuración
# (docker-compose.yml, .env, logstash/*, filebeat/*, etc.)

# 3. Ajustar kernel (IMPORTANTE para Elasticsearch)
sudo sysctl -w vm.max_map_count=262144

# 4. Iniciar
docker-compose up -d

# 5. Esperar 30-40 segundos y verificar
docker-compose ps

# 6. Abrir navegador
# http://localhost:5601
```

### Opción 2: Ubuntu Server virgen (paso a paso)

```bash
# 1. Update del sistema
sudo apt-get update && sudo apt-get upgrade -y

# 2. Instalar Docker
curl https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# 3. Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 4. Crear estructura y configuración
mkdir -p ~/minisoc/{logstash/conf.d,filebeat,suricata/rules}
cd ~/minisoc

# (Copiar todos los archivos de configuración aquí)

# 5. Ajustar kernel
sudo sysctl -w vm.max_map_count=262144

# 6. Iniciar
docker-compose up -d

# 7. Verificar (después de 1 minuto)
docker-compose ps
docker-compose logs -f

# 8. Kibana listo en 2-3 minutos
# http://localhost:5601
```

---

## ⚡ Comandos clave

| Comando | Función |
|---------|---------|
| `docker-compose up -d` | Iniciar todo en background |
| `docker-compose down` | Parar todo |
| `docker-compose ps` | Ver estado de servicios |
| `docker-compose logs -f` | Ver logs en tiempo real |
| `docker-compose logs elasticsearch` | Logs de un servicio específico |
| `docker-compose exec elasticsearch bash` | Entrar a un contenedor |
| `docker-compose restart` | Reiniciar todos los servicios |

---

## 📊 Enviar datos de prueba

Una vez que esté corriendo:

### Test 1: Enviar syslog
```bash
echo '<Sysmon>Test event</Sysmon>' | nc localhost 5000
```

### Test 2: Enviar JSON
```bash
curl -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "alert",
    "message": "Test alert",
    "severity": "high"
  }'
```

### Test 3: Ver en Kibana
1. Abrir http://localhost:5601
2. Ir a **Discover**
3. Crear data view: `syslog-*` o `events-*`
4. ¡Ver eventos!

---

## 🔍 Health Check

```bash
# Verificar que todo está bien
chmod +x health-check.sh
./health-check.sh
```

---

## ❌ Si algo falla

**Elasticsearch no inicia:**
```bash
sudo sysctl -w vm.max_map_count=262144
docker-compose restart elasticsearch
```

**No hay datos:**
```bash
# Ver logs de Logstash
docker-compose logs logstash

# Enviar test de nuevo
echo '<Test>' | nc localhost 5000

# Verificar índices creados
curl http://localhost:9200/_cat/indices?v
```

**Puertos en conflicto:**
```bash
# Ver qué está usando el puerto
sudo netstat -tlnp | grep 9200
sudo netstat -tlnp | grep 5601

# Si hay conflicto, editar docker-compose.yml
# Cambiar "9200:9200" por "9201:9200"
```

---

## 📈 Próximo paso

Una vez verificado:
1. Agregar **Suricata IDS**
2. Conectar **Windows VM con Sysmon**
3. Crear **Dashboards de alertas**
4. Configurar **Alertas automáticas a Telegram**

---

## 📚 Archivos necesarios

```
~/minisoc/
├── docker-compose.yml
├── .env
├── logstash/
│   ├── pipelines.yml
│   └── conf.d/
│       ├── 01-syslog.conf
│       └── 02-json.conf
├── filebeat/
│   └── filebeat.yml
└── health-check.sh
```

---

**¿Listo? ¡Empieza con:**
```bash
docker-compose up -d && sleep 30 && docker-compose ps
```

Si ves todos los containers en **Up** → ¡funciona! 🎉