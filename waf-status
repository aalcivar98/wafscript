#!/bin/bash

# waf-status-check.sh
# Script de verificación paso a paso del estado del WAF

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

function print_result() {
    if [ "$1" -eq 0 ]; then
        echo -e "${GREEN}[OK]${NC} $2"
    else
        echo -e "${RED}[ERROR]${NC} $2"
    fi
}

# FASE 1: Apache activo
echo -e "\n🔹 FASE 1: Verificando que Apache esté activo..."
sudo systemctl is-active --quiet apache2
apache_status=$?
print_result $apache_status "Apache está activo"

# FASE 2: ModSecurity instalado
echo -e "\n🔹 FASE 2: Verificando instalación de ModSecurity..."
modsec_ver=$(dpkg -s libapache2-mod-security2 2>/dev/null | grep Version)
if [ -n "$modsec_ver" ]; then
    echo -e "${GREEN}[OK]${NC} ModSecurity instalado: $modsec_ver"
else
    echo -e "${RED}[ERROR]${NC} ModSecurity no está instalado"
fi

# FASE 3: ModSecurity habilitado
echo -e "\n🔹 FASE 3: Verificando si ModSecurity está habilitado..."
if grep -q "SecRuleEngine On" /etc/modsecurity/modsecurity.conf; then
    echo -e "${GREEN}[OK]${NC} ModSecurity está habilitado en modo: ON"
elif grep -q "SecRuleEngine DetectionOnly" /etc/modsecurity/modsecurity.conf; then
    echo -e "${YELLOW}[ADVERTENCIA]${NC} ModSecurity está en modo: DETECTION ONLY"
else
    echo -e "${RED}[ERROR]${NC} No se encuentra la directiva SecRuleEngine activa"
fi

# FASE 4: Reglas OWASP activas
echo -e "\n🔹 FASE 4: Verificando reglas OWASP activas..."
if grep -q "/rules/" /etc/apache2/mods-enabled/security2.conf; then
    echo -e "${GREEN}[OK]${NC} Reglas OWASP están activas."
    grep "/rules/" /etc/apache2/mods-enabled/security2.conf
else
    echo -e "${RED}[ERROR]${NC} Reglas OWASP no están habilitadas."
fi

# Autoría

echo -e "\n${CYAN}Script elaborado por Alex Alcivar${NC}"

exit 0
