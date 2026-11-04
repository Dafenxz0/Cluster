#!/usr/bin/env bash
# SANITIZED HISTORICAL EXPERIMENT - NOT VERIFIED ON LIVE HARDWARE.
# Recovered from archived project files, names/addresses changed.
# WARNING: This script uses root, SSH tunnels, and writes systemd units.
# DO NOT EXECUTE without full review, authorization and adapting every path.
# This is separate from the HTTP request-level load-balancing architecture.
set -Eeuo pipefail

# cluster-rpc.sh
# Experimental distributed llama.cpp RPC mode for the existing 3-node cluster.
# Designed to coexist with the current RR stack:
#   RR llama-server :8000
#   RR API          :9000
#   Open WebUI      :3000
# Experimental distributed server:
#   llama RPC       :8010
#
# Run this script ONLY on the master (.110) as root.
#
# Usage:
#   ./cluster-rpc.sh install /home/cluster/models/MODEL.gguf
#   ./cluster-rpc.sh start
#   ./cluster-rpc.sh status
#   ./cluster-rpc.sh test "Hola, responde OK"
#   ./cluster-rpc.sh stop
#   ./cluster-rpc.sh remove
#
# Optional environment variables:
#   RPC_CTX=4096
#   RPC_THREADS=6
#   RPC_ALIAS=cluster-rpc
#   RPC_PORT=8010
#   FORCE=1             # bypass RAM preflight warning

MASTER_IP="192.168.50.10"
WORKER1_IP="192.168.50.11"
WORKER2_IP="192.168.50.12"
NODES=("$MASTER_IP" "$WORKER1_IP" "$WORKER2_IP")

SRC="/home/cluster/llama.cpp"
BUILD="$SRC/build-rpc"
RPC_BACKEND_PORT=50052

# Local forwarded ports on master for worker RPC servers.
TUNNEL1_PORT=51057
TUNNEL2_PORT=51059

DIST_PORT="${RPC_PORT:-8010}"
CTX="${RPC_CTX:-4096}"
RPC_THREADS="${RPC_THREADS:-6}"
ALIAS="${RPC_ALIAS:-cluster-rpc}"

CONF="/etc/cluster-rpc-experimental.conf"
RPC_UNIT="/etc/systemd/system/ggml-rpc-experimental.service"
TUNNEL_UNIT="/etc/systemd/system/cluster-rpc-tunnels-experimental.service"
DIST_UNIT="/etc/systemd/system/llama-rpc-experimental.service"

die() { echo "[ERROR] $*" >&2; exit 1; }
info() { echo -e "\n[+] $*"; }
warn() { echo -e "\n[!] $*" >&2; }

require_master() {
    [[ $EUID -eq 0 ]] || die "Ejecuta como root."
    local ip
    ip=$(hostname -I 2>/dev/null || true)
    [[ "$ip" == *"$MASTER_IP"* ]] || warn "No detecto $MASTER_IP en hostname -I. Este script esta pensado para .110."
}

ssh_node() {
    local ip="$1"; shift
    if [[ "$ip" == "$MASTER_IP" ]]; then
        "$@"
    else
        ssh -o BatchMode=yes -o ConnectTimeout=5 "root@$ip" "$@"
    fi
}

check_ssh() {
    info "Comprobando SSH sin contraseña..."
    for ip in "$WORKER1_IP" "$WORKER2_IP"; do
        ssh -o BatchMode=yes -o ConnectTimeout=5 "root@$ip" true \
            || die "SSH sin contraseña no funciona con $ip"
        echo "  OK $ip"
    done
}

build_node() {
    local ip="$1"
    info "Compilando backend RPC separado en $ip (NO toca build/ actual)..."
    local cmd="
set -Eeuo pipefail
test -d '$SRC' || { echo 'No existe $SRC'; exit 1; }
command -v cmake >/dev/null || { echo 'Falta cmake'; exit 1; }
cmake -S '$SRC' -B '$BUILD' \
  -DGGML_RPC=ON \
  -DGGML_NATIVE=ON \
  -DCMAKE_BUILD_TYPE=Release
cmake --build '$BUILD' --config Release -j4
test -x '$BUILD/bin/ggml-rpc-server'
test -x '$BUILD/bin/llama-server'
echo BUILD_OK
"
    if [[ "$ip" == "$MASTER_IP" ]]; then
        bash -lc "$cmd"
    else
        ssh root@"$ip" "bash -lc $(printf '%q' "$cmd")"
    fi
}

install_rpc_unit_node() {
    local ip="$1"
    local unit
    unit=$(cat <<EOF
[Unit]
Description=Experimental ggml RPC CPU backend
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Nice=5
CPUWeight=3000
WorkingDirectory=$BUILD/bin
Environment=GGML_RPC_NO_RDMA=1
ExecStart=$BUILD/bin/ggml-rpc-server -H 127.0.0.1 -p $RPC_BACKEND_PORT -t $RPC_THREADS -c
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
)
    if [[ "$ip" == "$MASTER_IP" ]]; then
        printf '%s\n' "$unit" > "$RPC_UNIT"
        systemctl daemon-reload
    else
        printf '%s\n' "$unit" | ssh root@"$ip" "cat > '$RPC_UNIT' && systemctl daemon-reload"
    fi
}

write_master_units() {
    local model="$1"

    cat > "$CONF" <<EOF
MODEL=$model
ALIAS=$ALIAS
CTX=$CTX
DIST_PORT=$DIST_PORT
EOF
    chmod 600 "$CONF"

    cat > "$TUNNEL_UNIT" <<EOF
[Unit]
Description=Experimental RPC SSH tunnels to cluster workers
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/bin/bash -lc 'set -e; \
  ssh -N -o BatchMode=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=3 \
      -L ${TUNNEL1_PORT}:127.0.0.1:${RPC_BACKEND_PORT} root@${WORKER1_IP} & \
  P1=\$!; \
  ssh -N -o BatchMode=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=3 \
      -L ${TUNNEL2_PORT}:127.0.0.1:${RPC_BACKEND_PORT} root@${WORKER2_IP} & \
  P2=\$!; \
  trap "kill \$P1 \$P2 2>/dev/null || true" TERM INT EXIT; \
  wait -n \$P1 \$P2'
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    cat > /usr/local/bin/llama-rpc-experimental-run <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
source /etc/cluster-rpc-experimental.conf

exec /home/cluster/llama.cpp/build-rpc/bin/llama-server \
  -m "$MODEL" \
  --host 0.0.0.0 \
  --port "$DIST_PORT" \
  --rpc 127.0.0.1:50052,127.0.0.1:51057,127.0.0.1:51059 \
  --tensor-split 1,1,1 \
  --split-mode layer \
  -ngl 999 \
  -t 2 \
  -c "$CTX" \
  -np 1 \
  --jinja \
  --alias "$ALIAS"
EOF
    chmod 755 /usr/local/bin/llama-rpc-experimental-run

    cat > "$DIST_UNIT" <<EOF
[Unit]
Description=Experimental distributed llama.cpp over RPC
After=network-online.target ggml-rpc-experimental.service cluster-rpc-tunnels-experimental.service
Wants=network-online.target
Requires=ggml-rpc-experimental.service cluster-rpc-tunnels-experimental.service

[Service]
Type=simple
User=root
Nice=5
CPUWeight=3000
WorkingDirectory=/root/cluster
ExecStart=/usr/local/bin/llama-rpc-experimental-run
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
}

ram_available_bytes_node() {
    local ip="$1"
    if [[ "$ip" == "$MASTER_IP" ]]; then
        awk '/MemAvailable:/ {print $2*1024}' /proc/meminfo
    else
        ssh root@"$ip" "awk '/MemAvailable:/ {print \\$2*1024}' /proc/meminfo"
    fi
}

ram_preflight() {
    source "$CONF"
    local size
    size=$(stat -c %s "$MODEL")
    # Approximate per-node model share + 1.5 GiB safety/headroom.
    local need=$(( size / 3 + 1610612736 ))

    info "Preflight de RAM (estimación conservadora por nodo)..."
    printf "  Modelo: %.2f GiB\n" "$(awk -v x="$size" 'BEGIN{print x/1024/1024/1024}')"
    printf "  Minimo orientativo libre por nodo: %.2f GiB\n" "$(awk -v x="$need" 'BEGIN{print x/1024/1024/1024}')"

    local bad=0
    for ip in "${NODES[@]}"; do
        local avail
        avail=$(ram_available_bytes_node "$ip" || echo 0)
        printf "  %s: %.2f GiB disponibles\n" "$ip" "$(awk -v x="$avail" 'BEGIN{print x/1024/1024/1024}')"
        (( avail < need )) && bad=1
    done

    if (( bad )) && [[ "${FORCE:-0}" != "1" ]]; then
        die "RAM disponible baja. No toco el RR. Libera RAM o repite con FORCE=1 si quieres asumir el riesgo."
    fi
}

wait_port() {
    local host="$1" port="$2" tries="${3:-30}"
    for ((i=1; i<=tries; i++)); do
        if timeout 1 bash -c ">/dev/tcp/$host/$port" 2>/dev/null; then
            return 0
        fi
        sleep 1
    done
    return 1
}

do_install() {
    local model="${1:-}"
    [[ -n "$model" ]] || die "Uso: $0 install /ruta/al/modelo.gguf"
    [[ -f "$model" ]] || die "No existe el modelo: $model"

    check_ssh

    info "Verificando que el stack RR actual existe. NO se modificara."
    systemctl cat llama-server >/dev/null 2>&1 || warn "No encuentro llama-server.service en master."
    systemctl cat cluster-api >/dev/null 2>&1 || warn "No encuentro cluster-api.service en master."

    for ip in "${NODES[@]}"; do
        build_node "$ip"
        install_rpc_unit_node "$ip"
    done

    write_master_units "$model"

    info "Instalación terminada."
    echo "  RR existente:        SIN CAMBIOS (:8000/:9000/:3000)"
    echo "  RPC experimental:    :8010 (por defecto)"
    echo "  RPC workers:         localhost:50052 mediante SSH"
    echo
    echo "Ahora ejecuta:"
    echo "  $0 start"
}

start_rpc_node() {
    local ip="$1"
    if [[ "$ip" == "$MASTER_IP" ]]; then
        systemctl start ggml-rpc-experimental
    else
        ssh root@"$ip" "systemctl start ggml-rpc-experimental"
    fi
}

do_start() {
    [[ -f "$CONF" ]] || die "Primero ejecuta install."
    source "$CONF"
    [[ -f "$MODEL" ]] || die "No existe MODEL=$MODEL"

    check_ssh
    ram_preflight

    info "Arrancando RPC CPU en los 3 PCs..."
    for ip in "${NODES[@]}"; do
        start_rpc_node "$ip"
        echo "  iniciado $ip"
    done

    info "Arrancando túneles SSH..."
    systemctl restart cluster-rpc-tunnels-experimental

    wait_port 127.0.0.1 "$RPC_BACKEND_PORT" 15 || die "RPC local master no responde."
    wait_port 127.0.0.1 "$TUNNEL1_PORT" 15 || die "Tunnel hacia .107 no responde."
    wait_port 127.0.0.1 "$TUNNEL2_PORT" 15 || die "Tunnel hacia .109 no responde."

    info "Arrancando llama-server distribuido en :$DIST_PORT..."
    systemctl restart llama-rpc-experimental

    # Loading may take time, especially through 1GbE.
    for ((i=1; i<=120; i++)); do
        if curl --noproxy '*' -fsS --max-time 2 "http://127.0.0.1:${DIST_PORT}/health" >/dev/null 2>&1; then
            echo
            echo "[OK] Servidor distribuido listo:"
            echo "     http://${MASTER_IP}:${DIST_PORT}"
            echo
            echo "El RR sigue en:"
            echo "     http://${MASTER_IP}:9000"
            return 0
        fi
        sleep 1
    done

    warn "El servidor no llegó a /health. Mira:"
    echo "  journalctl -u llama-rpc-experimental -n 100 --no-pager"
    return 1
}

do_stop() {
    info "Parando SOLO el modo RPC experimental..."
    systemctl stop llama-rpc-experimental 2>/dev/null || true
    systemctl stop cluster-rpc-tunnels-experimental 2>/dev/null || true

    for ip in "$MASTER_IP" "$WORKER1_IP" "$WORKER2_IP"; do
        if [[ "$ip" == "$MASTER_IP" ]]; then
            systemctl stop ggml-rpc-experimental 2>/dev/null || true
        else
            ssh root@"$ip" "systemctl stop ggml-rpc-experimental 2>/dev/null || true" || true
        fi
    done

    echo "[OK] RPC experimental parado. RR no se ha tocado."
}

do_status() {
    echo "================ RR ORIGINAL (solo lectura) ================"
    systemctl is-active llama-server 2>/dev/null || true
    systemctl is-active cluster-api 2>/dev/null || true
    docker ps --format '{{.Names}} {{.Status}} {{.Ports}}' 2>/dev/null | grep open-webui || true

    echo
    echo "================ RPC EXPERIMENTAL ================"
    echo "master RPC:"
    systemctl is-active ggml-rpc-experimental 2>/dev/null || true
    echo "tunnels:"
    systemctl is-active cluster-rpc-tunnels-experimental 2>/dev/null || true
    echo "distributed llama:"
    systemctl is-active llama-rpc-experimental 2>/dev/null || true

    for ip in "$WORKER1_IP" "$WORKER2_IP"; do
        echo "$ip RPC:"
        ssh root@"$ip" "systemctl is-active ggml-rpc-experimental 2>/dev/null || true" || true
    done

    echo
    if [[ -f "$CONF" ]]; then
        source "$CONF"
        echo "Modelo: $MODEL"
        echo "Alias:  $ALIAS"
        echo "CTX:    $CTX"
        echo "URL:    http://${MASTER_IP}:${DIST_PORT}"
    fi

    echo
    echo "Puertos experimentales:"
    ss -lntp 2>/dev/null | grep -E ":(${RPC_BACKEND_PORT}|${TUNNEL1_PORT}|${TUNNEL2_PORT}|${DIST_PORT})\\b" || true
}

do_test() {
    [[ -f "$CONF" ]] || die "Primero ejecuta install."
    source "$CONF"
    local prompt="${*:-Responde solamente: RPC OK}"

    info "Enviando prueba al servidor distribuido..."
    local payload
    payload=$(python3 - "$ALIAS" "$prompt" <<'PY'
import json, sys
print(json.dumps({
    "model": sys.argv[1],
    "messages": [{"role":"user","content":sys.argv[2]}],
    "stream": False,
    "max_tokens": 128,
    "temperature": 0.2
}))
PY
)

    local tmp
    tmp=$(mktemp)
    if ! curl --noproxy '*' -sS --max-time 300 \
        "http://127.0.0.1:${DIST_PORT}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "$payload" > "$tmp"; then
        rm -f "$tmp"
        die "curl fallo. Mira journalctl -u llama-rpc-experimental."
    fi

    python3 - "$tmp" <<'PY'
import json,sys
p=sys.argv[1]
raw=open(p,encoding="utf-8").read()
try:
    d=json.loads(raw)
except Exception:
    print(raw)
    raise SystemExit(1)
print(d.get("choices",[{}])[0].get("message",{}).get("content",""))
usage=d.get("usage")
if usage:
    print("\n--- usage ---")
    print(json.dumps(usage, indent=2))
PY
    rm -f "$tmp"
}

do_logs() {
    echo "===== distributed master ====="
    journalctl -u llama-rpc-experimental -n 120 --no-pager
    echo
    echo "===== master rpc ====="
    journalctl -u ggml-rpc-experimental -n 80 --no-pager
    echo
    echo "===== worker1 rpc ====="
    ssh root@"$WORKER1_IP" "journalctl -u ggml-rpc-experimental -n 80 --no-pager" || true
    echo
    echo "===== worker2 rpc ====="
    ssh root@"$WORKER2_IP" "journalctl -u ggml-rpc-experimental -n 80 --no-pager" || true
}

do_remove() {
    do_stop

    info "Eliminando SOLO unidades/config experimental (se conserva build-rpc)..."
    rm -f "$DIST_UNIT" "$TUNNEL_UNIT" "$CONF" /usr/local/bin/llama-rpc-experimental-run
    rm -f "$RPC_UNIT"
    systemctl daemon-reload

    for ip in "$WORKER1_IP" "$WORKER2_IP"; do
        ssh root@"$ip" "rm -f '$RPC_UNIT'; systemctl daemon-reload" || true
    done

    echo "[OK] Eliminado. RR original intacto."
    echo "Si también quieres borrar las compilaciones experimentales:"
    echo "  rm -rf '$BUILD'"
    echo "  ssh root@$WORKER1_IP \"rm -rf '$BUILD'\""
    echo "  ssh root@$WORKER2_IP \"rm -rf '$BUILD'\""
}

usage() {
    cat <<EOF
Uso:
  $0 install /ruta/al/modelo.gguf
  $0 start
  $0 stop
  $0 status
  $0 test "pregunta"
  $0 logs
  $0 remove

Variables opcionales:
  RPC_CTX=4096
  RPC_THREADS=6
  RPC_ALIAS=cluster-rpc
  RPC_PORT=8010
  FORCE=1
EOF
}

require_master

case "${1:-}" in
    install)
        shift
        do_install "${1:-}"
        ;;
    start)
        do_start
        ;;
    stop)
        do_stop
        ;;
    status)
        do_status
        ;;
    test)
        shift
        do_test "$@"
        ;;
    logs)
        do_logs
        ;;
    remove)
        do_remove
        ;;
    *)
        usage
        exit 1
        ;;
esac
