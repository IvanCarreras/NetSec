# Homelab Cybersecurity — Fase 1

Red base con targets web vulnerables accesibles desde Windows / red local.

---

## Estructura de red

```
DMZ_NET   10.10.10.0/24   → Nginx RP + DVWA + Juice Shop (aislados)
INTERNAL  10.10.20.0/24   → Reservada para SIEM (Fase 2)
MGMT_NET  10.10.30.0/24   → Portainer

Puertos expuestos al host (y por tanto a la red local):
  :80    → HTTP  (redirige a HTTPS)
  :443   → DVWA
  :8443  → Juice Shop
  :9000  → Portainer
```

---

## Instalación en Ubuntu Server

### Paso 1 — Instalar Docker
```bash
chmod +x install-docker.sh
./install-docker.sh

# Cierra la sesión SSH y vuelve a entrar (grupo docker)
exit
ssh usuario@<IP_SERVIDOR>
```

### Paso 2 — Levantar el lab
```bash
chmod +x setup.sh teardown.sh
./setup.sh
```

---

## Acceso desde Windows / red local

Sustituye `<IP>` por la IP de tu Ubuntu Server (ej: `192.168.1.50`).

| Servicio    | URL                          | Credenciales     |
|-------------|------------------------------|------------------|
| DVWA        | `https://<IP>`               | admin / password |
| Juice Shop  | `https://<IP>:8443`          | registro libre   |
| Portainer   | `http://<IP>:9000`           | crear al entrar  |

> El certificado SSL es self-signed. En el navegador: **Avanzado → Continuar**.

> Primera vez en DVWA: navega a **Setup / Reset Database** antes de atacar.

---

## Saber la IP del servidor (desde Ubuntu)

```bash
ip a | grep "inet " | grep -v 127
# o
hostname -I
```

---

## Logs en tiempo real (desde Ubuntu Server)

```bash
# Todos los accesos (JSON)
docker exec nginx-rp tail -f /var/log/nginx/dvwa_access.log

# Juice Shop
docker exec nginx-rp tail -f /var/log/nginx/juice_access.log

# Errores del proxy
docker exec nginx-rp tail -f /var/log/nginx/error.log

# Estado de todos los contenedores
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

---

## Parar el lab

```bash
./teardown.sh            # Para contenedores, conserva datos
./teardown.sh --purge    # Borra todo, incluidos volúmenes
```

---

## Fases siguientes

- **Fase 2** — Elastic Stack (Elasticsearch + Kibana + Logstash + Filebeat)
- **Fase 3** — Suricata IDS inline
- **Fase 4** — Detection Rules en Kibana
- **Fase 5** — Respuesta automática: alerta → bloqueo firewall
