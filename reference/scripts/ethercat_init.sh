#!/bin/bash

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then
    echo "Por favor execute com: sudo ./ethercat_start.sh"
    exit 1
fi

echo "Unbinding igb..."
echo 0000:03:00.0 > /sys/bus/pci/drivers/igb/unbind

echo "Starting EtherCAT..."
/etc/init.d/ethercat start

echo "Feito!"

