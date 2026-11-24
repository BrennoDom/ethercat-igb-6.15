#!/bin/bash

if [ $# -ne 3 ]; then
    echo "Need 3 arguments: 1) kernel source dir, 2) previous version, 3) version to add"
    exit 1
fi

KERNELDIR=$1
PREVER=$2
KERNELVER=$3

IGBDIR=drivers/net/ethernet/intel/igb

FILES="e1000_82575.c e1000_82575.h e1000_defines.h e1000_hw.h e1000_i210.c e1000_i210.h e1000_mac.c e1000_mac.h e1000_mbx.c e1000_mbx.h e1000_nvm.c e1000_nvm.h e1000_phy.c e1000_phy.h e1000_regs.h igb_ethtool.c igb.h igb_hwmon.c igb_main.c igb_ptp.c igb_xsk.c"

set -x

for f in $FILES; do
    echo $f
    o=${f/\./-$KERNELVER-orig.}
    e=${f/\./-$KERNELVER-ethercat.}
    cp -v $KERNELDIR/$IGBDIR/$f $o
    chmod 644 $o
    cp -v $o $e
    op=${f/\./-$PREVER-orig.}
    ep=${f/\./-$PREVER-ethercat.}
    diff -up $op $ep | patch -p1 --no-backup-if-mismatch $e
    sed -i s/$PREVER-ethercat.h/$KERNELVER-ethercat.h/ $e
    git add $o $e
    echo -e "\t$e \\" >> Makefile.am
    echo -e "\t$o \\" >> Makefile.am
done

################## INJETAR XSK CORRETAMENTE ##################

# Ajustar Makefile.am LOCAL (não do kernel!)
echo "➡ Ajustando Makefile.am (não compilar igb_xsk.o separadamente)"
sed -i '/igb_xsk\.o/d' Makefile.am

# Inserir include no arquivo LOCAL gerado pelo update.sh
MAINFILE="igb_main-${KERNELVER}-ethercat.c"
if ! grep -q "igb_xsk-${KERNELVER}-ethercat.c" "$MAINFILE"; then
    echo -e "\n#ifdef ENABLE_XSK\n#include \"igb_xsk-${KERNELVER}-ethercat.c\"\n#endif" >> "$MAINFILE"
    echo "✔ Include do XSK inserido no $MAINFILE"
else
    echo "✔ Include já existe (não duplicando)"
fi

echo
echo "⚙ Para ativar XSK na compilação use:"
echo "   make CFLAGS+=-DENABLE_XSK"
echo
echo "Don't forget to update Makefile.am!"
