#!/bin/bash

###=============================================
### 🧠 Configuración de Red – Ubuntu-APPWEB
### Autor: Mag. en Programación y Ciberseguridad
### Funcionalidad: Enrutamiento forzado por WAF + failover controlado
###=============================================

set -e

# VARIABLES
ETH_WAF="eth1"
ETH_OTRA="eth0"
STATIC_IP="10.0.3.20/24"
GATEWAY_WAF="10.0.3.10"
DNS1="8.8.8.8"
DNS2="1.1.1.1"
NETPLAN_CFG="/etc/netplan/01-netcfg.yaml"
DEFAULT_ROUTE_FILE="/etc/network/if-up.d/check-default-route"
WATCHDOG_SCRIPT="/usr/local/bin/waf-watchdog.sh"
CRON_ENTRY="@reboot root /usr/local/bin/waf-watchdog.sh &"

echo "[FASE 0] Preparando entorno seguro de red..."

# FASE 1: Desactivar interfaz secundaria si existe
if ip link show $ETH_OTRA &>/dev/null; then
    echo "[FASE 1] Desactivando $ETH_OTRA..."
    ip link set $ETH_OTRA down || echo "[!] No se pudo bajar $ETH_OTRA."
fi

# FASE 2: Asignar IP estática con netplan
echo "[FASE 2] Asignando IP estática a $ETH_WAF..."
cat <<EOF > $NETPLAN_CFG
network:
  version: 2
  ethernets:
    $ETH_WAF:
      dhcp4: no
      addresses: [$STATIC_IP]
      gateway4: $GATEWAY_WAF
      nameservers:
        addresses: [$DNS1, $DNS2]
EOF

netplan apply
sleep 2

# FASE 3: Establecer gateway por defecto
echo "[FASE 3] Configurando gateway por defecto a través de $GATEWAY_WAF..."
ip route del default || true
ip route add default via $GATEWAY_WAF dev $ETH_WAF

# FASE 4: Verificación básica
echo "[FASE 4] Verificando conectividad con WAF..."
if ! ping -c 2 $GATEWAY_WAF &>/dev/null; then
    echo "[✗] No se puede contactar con el WAF. Abortando configuración."
    exit 1
fi

# FASE 5: Crear watchdog de monitoreo y recuperación
echo "[FASE 5] Configurando watchdog para fallo de WAF..."

cat <<'EOF' > $WATCHDOG_SCRIPT
#!/bin/bash
# Script watchdog para monitorear disponibilidad del WAF

GATEWAY="10.0.3.10"
ETH="eth1"
TRIES=3
LOGTAG="APPWEB-WAF-WATCHDOG"

while true; do
    if ping -c $TRIES $GATEWAY &>/dev/null; then
        sleep 60
        continue
    fi

    logger -t $LOGTAG "[⚠] No hay respuesta del WAF ($GATEWAY). Intentando recuperación..."

    # Intentar restaurar ruta por defecto
    ip route del default &>/dev/null
    ip route add default via $GATEWAY dev $ETH

    # Verificar si restauración fue efectiva
    if ping -c $TRIES $GATEWAY &>/dev/null; then
        logger -t $LOGTAG "[✔] Conexión restaurada exitosamente."
    else
        logger -t $LOGTAG "[✗] Falla persistente del WAF. Reiniciando red como contingencia..."
        systemctl restart systemd-networkd || systemctl restart networking
        sleep 30
    fi
    sleep 60
done
EOF

chmod +x $WATCHDOG_SCRIPT

# FASE 6: Asegurar ejecución en arranque
if ! grep -q "$WATCHDOG_SCRIPT" /etc/crontab; then
    echo "$CRON_ENTRY" >> /etc/crontab
    echo "[FASE 6] Watchdog registrado para autoejecución en arranque."
fi

# FASE 7: Verificación de red final
echo "[FASE 7] Estado final de red:"
ip addr show $ETH_WAF
ip route show

# MENSAJES FINALES
cat <<EOF

[✔] Configuración completada.

📌 Todo el tráfico de Ubuntu-APPWEB está forzado a pasar por Ubuntu-WAF ($GATEWAY_WAF).
🔒 Se instaló un watchdog en: $WATCHDOG_SCRIPT
🔁 Si el WAF falla, se reestablece la ruta o se reinicia la red.

📡 Requisitos en Ubuntu-WAF:
→ IP forwarding activado:
   sudo sysctl -w net.ipv4.ip_forward=1
→ NAT habilitado:
   sudo iptables -t nat -A POSTROUTING -o ethX -j MASQUERADE

🛡 Recomendación:
→ Usar Suricata, Snort o Fail2Ban en el WAF para protección L7.
→ Monitorear tráfico con ntopng, Zabbix o ELK Stack.

EOF
