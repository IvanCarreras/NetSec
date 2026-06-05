# Homelab Cybersecurity — Fase 1

Red base con targets web vulnerables y reverse proxy.  
Diseñado para practicar pentesting web + preparar la ingesta de logs en Fase 2 (SIEM).

---

## Estructura de red

```
WAN_NET  192.168.100.0/24  → Zona atacante (Kali)
DMZ_NET   10.10.10.0/24   → Targets web + Nginx RP
INTERNAL  10.10.20.0/24   → Reservada para SIEM (Fase 2)
MGMT_NET  10.10.30.0/24   → Portainer
```

## Arranque rápido

```bash
chmod +x setup.sh teardown.sh
./setup.sh
```

## Acceso a los servicios

| Servicio    | URL                                  | Credenciales        |
|-------------|--------------------------------------|---------------------|
| DVWA        | https://dvwa.homelab.local           | admin / password    |
| Juice Shop  | https://juice.homelab.local:8443     | (registro libre)    |
| Portainer   | http://localhost:9000                | (crear al entrar)   |

> Primera vez en DVWA: ve a Setup/Reset Database antes de atacar.

## Conectarse a Kali

```bash
docker exec -it kali-attacker bash
```

## Comandos útiles desde Kali

```bash
# Reconocimiento
nmap -sV -sC 192.168.100.10
nmap -p 80,443,8443 192.168.100.10

# Fuzzing de directorios
gobuster dir -u https://192.168.100.10 -w /usr/share/wordlists/dirb/common.txt -k

# SQLi automatizado contra DVWA
sqlmap -u "https://192.168.100.10/vulnerabilities/sqli/?id=1&Submit=Submit" \
       --cookie="PHPSESSID=<tu_sesion>;security=low" \
       --dbs --batch -k

# Nikto — escaneo de vulnerabilidades web
nikto -h https://192.168.100.10 -ssl

# Brute force login (genera alertas de rate limiting en Nginx)
hydra -l admin -P /usr/share/wordlists/rockyou.txt \
      192.168.100.10 https-post-form \
      "/login.php:username=^USER^&password=^PASS^:Login Failed" -V
```

## Ver logs en tiempo real

```bash
# Todos los accesos al proxy (JSON)
docker exec nginx-rp tail -f /var/log/nginx/access.log | python3 -m json.tool

# Solo logs de DVWA
docker exec nginx-rp tail -f /var/log/nginx/dvwa_access.log

# Errores Nginx
docker exec nginx-rp tail -f /var/log/nginx/error.log

# Estado de todos los contenedores
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Networks}}"
```

## Parar el lab

```bash
./teardown.sh            # Para contenedores, conserva datos
./teardown.sh --purge    # Borra todo incluyendo volúmenes
```

## Fases siguientes

- **Fase 2** — Elastic Stack (Elasticsearch + Kibana + Logstash + Filebeat)
- **Fase 3** — Suricata IDS inline entre WAN y DMZ
- **Fase 4** — Detection Rules en Kibana (SQLi, port scan, brute force)
- **Fase 5** — Respuesta automática: alerta Kibana → bloqueo firewall
