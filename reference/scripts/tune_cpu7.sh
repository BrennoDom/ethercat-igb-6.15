#!/bin/bash
CPU=7
OTHER_CPUS="0-6"

if [ "$EUID" -ne 0 ]; then
   echo "Use: sudo ./tune_cpu7.sh"
   exit 1
fi

echo "--------------------------------------------"
echo "Isolando CPU$CPU e limpando IRQs / kthreads"
echo "--------------------------------------------"

##############################################
# 1. Expulsar todos os IRQs do CPU7
##############################################
echo ">> Movendo IRQs para CPUs $OTHER_CPUS..."

for IRQ in $(ls /proc/irq | grep -E '^[0-9]+$'); do
    AFF="/proc/irq/$IRQ/smp_affinity_list"
    if [ -f "$AFF" ]; then
        echo $OTHER_CPUS > $AFF 2>/dev/null
    fi
done

##############################################
# 2. Expulsar kernel threads migráveis
##############################################
echo ">> Movendo kthreads da CPU$CPU para CPUs $OTHER_CPUS..."

for PID in $(ps -eLo pid,psr,cls,comm | awk '$2=='"$CPU"' && $3!="FF" {print $1}'); do
    taskset -pc $OTHER_CPUS $PID >/dev/null 2>&1
done

##############################################
# 3. Ajustes de rede RPS/NAPI (evita backlog_napi/7)
##############################################
echo ">> Limpando RPS / NAPI da CPU$CPU..."

for iface in /sys/class/net/*/queues/rx-*; do
    echo $OTHER_CPUS > $iface/rps_cpus 2>/dev/null
done

##############################################
# 4. Fixar EtherCAT somente no CPU7
##############################################
ETHER_PID=$(pgrep EtherCAT-IDLE)

if [ ! -z "$ETHER_PID" ]; then
    echo ">> Fixando EtherCAT-IDLE no CPU$CPU"
    taskset -pc $CPU $ETHER_PID
else
    echo "EtherCAT-IDLE ainda não iniciado."
fi

##############################################
# 5. Ajustes avançados de latência
##############################################
echo ">> Ajustando parâmetros do kernel..."

sysctl -w kernel.sched_rt_runtime_us=-1
sysctl -w kernel.timer_migration=0
sysctl -w vm.stat_interval=120

echo ""
echo "--------------------------------------------"
echo "CPU$CPU isolado e limpo."
echo "Use: ps -eLo pid,psr,comm | grep \" $CPU \""
echo "--------------------------------------------"

