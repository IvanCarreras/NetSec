# MiniSOC - Guía de Instalación Completa

## 📋 Índice
1. [Requisitos previos](#requisitos-previos)
2. [Instalación rápida](#instalación-rápida)
3. [Setup manual paso a paso](#setup-manual-paso-a-paso)
4. [Estructura de directorios](#estructura-de-directorios)
5. [Verificación y testing](#verificación-y-testing)
6. [Troubleshooting](#troubleshooting)

---

## Requisitos Previos

### Hardware mínimo
- **RAM**: 8GB (idealmente 10GB+ para Elasticsearch)
- **CPU**: 4 vCPU (Intel i7 = suficiente)
- **Disco**: 20GB mínimo para datos iniciales
- **SO**: Ubuntu Server 20.04 LTS o superior (recomendado 22.04)

### Software
- Docker CE (Community Edition)
- Docker Compose 2.x
- sudo access

---

## Instalación Rápida

### Opción 1: Con script automatizado

```bash
# 1. Descargar el script
sudo curl -o /tmp/setup-minisoc.sh https://tu-servidor/setup-minisoc.sh
sudo chmod +x /tmp/setup-minisoc.sh

# 2. Ejecutar (requiere sudo)
sudo /tmp/setup-minisoc.sh

# 3. El script creará /opt/minisoc automáticamente
```

### Opción 2: Manual (recomendado para aprender)

```bash
# 1. Update del sistema
sudo apt-get update && sudo apt-get upgrade -y

# 2. Instalar Docker
sudo apt-get install -y curl
curl https://get.docker.com | sh
sudo usermod -aG docker $USER

# 3. Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 4. Ajustar kernel para Elasticsearch
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

# 5. Crear estructura de directorios
mkdir -p ~/minisoc/{logstash/conf.d,filebeat,suricata/rules,data}
cd ~/minisoc
```

---

## Setup Manual Paso a Paso

### Paso 1: Crear estructura de directorios

```bash
# Crear directorio principal (como root o con sudo)
sudo mkdir -p /opt/minisoc
cd /opt/minisoc

# Crear subdirectorios
sudo mkdir -p logstash/conf.d
sudo mkdir -p filebeat
sudo mkdir -p suricata/rules
sudo mkdir -p data

# Cambiar permisos si estás usando ~/minisoc en home
sudo chown -R $USER:$USER /opt/minisoc
chmod 755 /opt/minisoc
```

### Paso 2: Crear archivos de configuración

**a) docker-compose.yml**
```bash
# Copiar el docker-compose.yml completo a:
/opt/minisoc/docker-compose.yml
```

**b) Crear archivo .env**
```bash
cat > /opt/minisoc/.env << 'EOF'
ELASTICSEARCH_VERSION=8.11.0
ES_MEMORY_MIN=2g
ES_MEMORY_MAX=2g
KIBANA_VERSION=8.11.0
KIBANA_PORT=5601
LOGSTASH_VERSION=8.11.0
LOGSTASH_MEMORY=512m
FILEBEAT_VERSION=8.11.0
ELASTICSEARCH_USER=elastic
ELASTICSEARCH_PASSWORD=changeme
NETWORK_NAME=minisoc-network
ES_PORT=9200
KIBANA_HTTP_PORT=5601
LOGSTASH_SYSLOG_PORT=5000
LOGSTASH_BEATS_PORT=5044
LOGSTASH_HTTP_PORT=8080
ENVIRONMENT=homelab
STACK_NAME=minisoc
EOF
```

**c) Crear pipeline de Logstash**
```bash
# pipelines.yml
cat > /opt/minisoc/logstash/pipelines.yml << 'EOF'
- pipeline.id: syslog-pipeline
  path.config: "/usr/share/logstash/pipeline/01-syslog.conf"
  pipeline.workers: 2

- pipeline.id: json-pipeline
  path.config: "/usr/share/logstash/pipeline/02-json.conf"
  pipeline.workers: 2
EOF

# Copiar 01-syslog.conf
# Copiar 02-json.conf
```

**d) Crear configuración de Filebeat**
```bash
# Copiar filebeat.yml a /opt/minisoc/filebeat/filebeat.yml
```

### Paso 3: Ajustar permisos de Docker

```bash
# Para que Logstash pueda procesar archivos
sudo chmod 666 /var/run/docker.sock

# O agregar tu usuario al grupo docker (más seguro)
sudo usermod -aG docker $USER
# Requiere logout/login
```

### Paso 4: Iniciar el stack

```bash
cd /opt/minisoc

# Crear redes y volúmenes
docker-compose up -d

# Esto descargará imágenes (puede tomar 5-10 minutos en primera ejecución)
```

### Paso 5: Verificar que todo está corriendo

```bash
# Ver estado de containers
docker-compose ps

# Debería mostrar algo como:
# NAME                    STATUS              PORTS
# minisoc-elasticsearch   Up 2 minutes        0.0.0.0:9200->9200/tcp
# minisoc-kibana          Up 1 minute         0.0.0.0:5601->5601/tcp
# minisoc-logstash        Up 1 minute         0.0.0.0:5000->5000/tcp
# minisoc-filebeat        Up 1 minute
```

### Paso 6: Acceder a Kibana

Abrir navegador:
```
http://localhost:5601
```

Debería ver la interfaz de Kibana lista para usar.

---

## Estructura de Directorios

```
/opt/minisoc/
├── docker-compose.yml          # Configuración principal de Docker
├── .env                         # Variables de entorno
├── data/                        # Datos persistentes
│   └── elasticsearch/
├── logstash/
│   ├── pipelines.yml           # Definición de pipelines
│   └── conf.d/
│       ├── 01-syslog.conf      # Pipeline para syslog
│       └── 02-json.conf        # Pipeline para JSON
├── filebeat/
│   └── filebeat.yml            # Configuración de recolección
└── suricata/
    └── rules/                   # (Para futura expansión)
```

---

## Verificación y Testing

### Test 1: Enviar logs de prueba a Logstash

```bash
# Enviar un evento de prueba por TCP (port 5000)
echo '<Sysmon>This is a test message</Sysmon>' | nc localhost 5000

# Enviar JSON por HTTP (port 8080)
curl -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "alert",
    "timestamp": "2024-01-15T10:30:00Z",
    "message": "Test alert",
    "severity": "high"
  }'
```

### Test 2: Verificar en Kibana

1. Ir a **Kibana** → **Discover**
2. Crear nuevo data view con patrón `syslog-*` o `events-*`
3. Debería ver los eventos que enviaste

### Test 3: Revisar logs de Docker

```bash
# Ver logs de Elasticsearch
docker-compose logs -f elasticsearch

# Ver logs de Logstash
docker-compose logs -f logstash

# Ver logs de Kibana
docker-compose logs -f kibana

# Ver todo
docker-compose logs -f
```

---

## Troubleshooting

### ❌ Elasticsearch no inicia

**Error**: `vm.max_map_count too low`

```bash
# Solución:
sudo sysctl -w vm.max_map_count=262144
sudo tee -a /etc/sysctl.conf << EOF
vm.max_map_count=262144
EOF
```

### ❌ Logstash conecta pero no parsea

**Revisar pipeline**:
```bash
# Ver logs de Logstash
docker-compose logs logstash

# Verificar sintaxis de pipeline
docker-compose exec logstash bash
logstash -t -f /usr/share/logstash/pipeline/01-syslog.conf
```

### ❌ No hay datos en Kibana

1. Verificar que Elasticsearch está corriendo:
   ```bash
   curl http://localhost:9200
   ```

2. Revisar indices creados:
   ```bash
   curl http://localhost:9200/_cat/indices?v
   ```

3. Si no hay índices, enviar datos de prueba (ver Test 1)

### ❌ Kibana dice "No matching indices"

1. Ir a **Stack Management** → **Index Patterns**
2. Crear nuevo patrón: `syslog-*` o `events-*`
3. Seleccionar timestamp field: `@timestamp`
4. Guardar y volver a **Discover**

### ❌ Puertos en uso

```bash
# Ver qué está usando puerto 9200, 5601, etc.
sudo netstat -tlnp | grep LISTEN

# Cambiar puerto en docker-compose.yml si es necesario
# Ejemplo: "9201:9200" en lugar de "9200:9200"
```

---

## Comandos Útiles

```bash
# Reiniciar stack
docker-compose restart

# Parar sin eliminar datos
docker-compose stop

# Reiniciar desde cero (BORRA DATOS)
docker-compose down -v

# Ver recursos utilizados
docker stats

# Entrar a contenedor para debugging
docker-compose exec elasticsearch bash
docker-compose exec logstash bash

# Ver estado de servicios
docker-compose ps -a

# Limpiar imágenes no usadas
docker image prune -a
```

---

## Próximos Pasos

Una vez que tengas el stack corriendo:

1. **Agregar Suricata IDS** - Para generar alertas de red
2. **Conectar Sysmon** - Desde Windows VM
3. **Crear Dashboards** - En Kibana
4. **Configurar Alertas** - KQL alerts a Telegram
5. **Agregar T-Pot** - Como honeypot generador de tráfico malicioso

---

## Recursos

- 📖 [Documentación Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/current/)
- 📖 [Documentación Kibana](https://www.elastic.co/guide/en/kibana/current/)
- 📖 [Documentación Logstash](https://www.elastic.co/guide/en/logstash/current/)
- 📖 [Documentación Filebeat](https://www.elastic.co/guide/en/beats/filebeat/current/)

---

**¿Dudas?** Revisa los logs con `docker-compose logs -f` 🔍