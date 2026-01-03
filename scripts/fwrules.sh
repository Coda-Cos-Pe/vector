#!/bin/sh

source .config

# Configurações
DEST_FILE="/etc/vector/firewall_rules.json"

# Arquivos
RAW_JSON="/tmp/opnsense_rules_raw.json"
VECTOR_JSON="/etc/vector/firewall_rules.csv"
MTIME_FILE="/tmp/firewall_rules.mtime"

# 1. Baixa o JSON cru do firewall
curl -s -q -k -XGET "${FW_URL}" -H "authorization: $AUTHORIZATION" > "${RAW_JSON}"
CURL_EXIT=$?

if [ $CURL_EXIT -ne 0 ]; then
    echo "$(date): Erro no CURL (Exit Code: $CURL_EXIT). Verifique URL/Rede."
    exit 1
fi


# Verifica se o download foi válido (se é um JSON válido)
if ! jq -e . "${RAW_JSON}" >/dev/null 2>&1; then
    echo "$(date): Erro ao baixar JSON do firewall. Abortando."
    exit 1
fi

# 2. Extrai o mtime atual do JSON baixado
CURRENT_MTIME=$(jq -r '.mtime' "${RAW_JSON}")

# 3. Lê o último mtime salvo (se existir)
if [ -f "${MTIME_FILE}" ]; then
    LAST_MTIME=$(cat "${MTIME_FILE}")
else
    LAST_MTIME="0"
fi

# 4. Comparação: Se forem iguais, não faz nada
if [ "$CURRENT_MTIME" == "$LAST_MTIME" ]; then
    # Opcional: Descomente para debug
    echo "$(date): Nenhuma alteração nas regras (mtime: $CURRENT_MTIME). Ignorando."
    rm "${RAW_JSON}"
    exit 0
fi

# ==========================================================
# SE CHEGOU AQUI, HOUVE MUDANÇA!
# ==========================================================

echo "$(date): Mudança detectada! Atualizando regras ($LAST_MTIME -> $CURRENT_MTIME)..."

# 5. Processa o JSON para o formato do Vector
#
jq -r '["tracker_id", "rule_description"], ([.labels[] | {tracker_id: .rid, rule_description: .descr}] | unique_by(.tracker_id)[] | [.tracker_id, .rule_description]) | @csv' "${RAW_JSON}" > "${VECTOR_JSON}.tmp"

# 6. Valida e Aplica
if [ -s "${VECTOR_JSON}.tmp" ]; then
    mv "${VECTOR_JSON}.tmp" "${VECTOR_JSON}"
    
    # Salva o novo mtime para a próxima execução
    echo "$CURRENT_MTIME" > "${MTIME_FILE}"
    
    # Recarrega o Vector suavemente (SIGHUP)
    rc-service vector -v reload
    
    echo "$(date): Sucesso. Vector recarregado."
else
    echo "$(date): Erro ao processar JSON com JQ."
fi

# Limpeza
rm "${RAW_JSON}"
