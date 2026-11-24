# EtherCAT igb driver for Linux 6.14 / 6.15

The IgH EtherLab EtherCAT Master 1.6 (`stable-1.6`, version 1.6.8) with its native
**igb** EtherCAT device driver ported to **Linux 6.14 and 6.15**. Upstream `stable-1.6`
only ships igb sources up to Linux 6.12.

The igb driver covers Intel I210/I211, 82575/82576/82580 and I350/I354 NICs.

## Status

| | |
|---|---|
| Kernel in use | `6.15.9-rt2-bhf4-224362-a50797864f54` (Beckhoff, `SMP PREEMPT_RT`) |
| Hardware in use | Beckhoff IPC, Intel Core i7-9700E, **Intel I210** (`8086:1533`) |
| OS | Debian 13 (trixie), gcc 14.2 |
| Result | `ec_master`, `ec_igb` and `ec_generic` load and the master attaches to the I210 |
| Linux 6.14 | sources included, not tested on hardware |

A clean build from this repository (`configure` + `make modules`) was also checked with
gcc 15 against the reference headers package (see below). It produces an `ec_igb.ko`
with the same symbols as the module running on the IPC.

## What changed vs. upstream

Base: [EtherLab `stable-1.6`](https://gitlab.com/etherlab.org/ethercat) at commit `2543cc55`.
The port is in the second and third commits of this repository
(`git diff --stat HEAD~3 HEAD~1`):

- `devices/igb/*-6.14-*` and `devices/igb/*-6.15-*`: the kernel's igb sources (`-orig`)
  and their EtherCAT-enabled versions (`-ethercat`) for each kernel.
- `devices/igb/igb_xsk-*`: AF_XDP zero-copy support (`igb_xsk.c`), which recent kernels
  split out of `igb_main.c`. `igb_main` calls into it, so it is linked into `ec_igb.ko`.
- `devices/igb/Kbuild.in`: links `igb_xsk-<ver>-ethercat.o` into `ec_igb` when that file
  exists for the selected kernel. Kernels without it, such as 6.12 and older, are unaffected.
- `devices/igb/update.sh`: also imports `igb_xsk.c`. It has an optional step that appends
  an `#include` of the xsk file to `igb_main` under `ENABLE_XSK`. The sources in this
  repository do not use that step.
- `devices/igb/Makefile.am`: file lists for 6.14 and 6.15.
- `*.rej`: rejects left over from applying the EtherCAT patches to the new kernel
  sources. They are kept for reference and are not built.

The upstream README is kept as [`README-EtherLab.md`](README-EtherLab.md).

## Build and install

Requirements: headers for the target kernel (6.14.x or 6.15.x) and the build tools.

```bash
sudo apt install build-essential autoconf automake libtool pkg-config
git clone git@github.com:BrennoDom/ethercat-igb-6.15.git
cd ethercat-igb-6.15
./bootstrap
./configure --prefix=/usr/local/etherlab --disable-8139too --disable-eoe \
            --enable-generic --enable-igb
# to build for a kernel other than the running one, add:
#   --with-linux-dir=/lib/modules/<kernel-release>/build
make -j"$(nproc)"
make modules -j"$(nproc)"
sudo make install
sudo make modules_install
sudo depmod -a
```

`configure` picks the igb sources that match the kernel's `major.minor`. To force
a version, use `--with-igb-kernel=6.15`.

## Configuration

1. Copy `reference/ethercat/sysconfig-ethercat` to `/etc/sysconfig/ethercat` and set:
   - `MASTER0_DEVICE="<MAC of the EtherCAT NIC>"`
   - `DEVICE_MODULES="igb"`
2. Release the NIC from the regular `igb` driver and start the master.
   `reference/scripts/ethercat_init.sh` does both steps. It uses the PCI address
   `0000:03:00.0`; find yours with `lspci -D | grep -i ethernet`.
3. Check it with `/usr/local/etherlab/bin/ethercat master`.

## Reference platform (release `v1.6.8-igb-6.15`)

The release contains the exact kernel the driver runs on, so the setup can be
reproduced on another PC. That kernel build is no longer available from Beckhoff's
apt repository.

| File | Purpose |
|---|---|
| `linux-image-6.15.9-rt2-bhf4-224362-a50797864f54_…_amd64.deb` | The PREEMPT_RT kernel, repacked from the installed package. The md5 sums of all 433 files match the original package. |
| `linux-headers-6.15.9-rt2-bhf4-224362-a50797864f54_…_amd64.deb` | Headers for building modules. Generated with `scripts/package/install-extmod-build`, the same procedure as `make bindeb-pkg`. |
| `ethercat-1.6.8-igb-…-prebuilt.tar.gz` | This driver prebuilt for that kernel, together with the `/usr/local/etherlab` userspace. Extract with `sudo tar -xzf … -C /` and then run `sudo depmod -a`. |
| `linux-source-…-prepared.tar.zst` | The full kernel tree the modules were built against: source, `.config`, `Module.symvers`, and the build tools. |
| `linux-upstream_6.15.9-224362-a50797864f54*` | Debian source package and the original build log, for rebuilding the kernel. |

Checksums are in [`reference/SHA256SUMS`](reference/SHA256SUMS). Verify downloads with
`sha256sum -c reference/SHA256SUMS --ignore-missing`.

### Installing the reference kernel

```bash
sudo apt install ./linux-image-6.15.9-rt2-bhf4-224362-a50797864f54_6.15.9-224362-a50797864f54-1_amd64.deb \
                 ./linux-headers-6.15.9-rt2-bhf4-224362-a50797864f54_6.15.9-224362-a50797864f54-1_amd64.deb
```

- The package's `postinst` builds the initramfs and updates GRUB or systemd-boot
  through `/etc/kernel/postinst.d`.
- **Secure Boot:** the kernel is not signed for shim. Turn Secure Boot off.
- **CPU isolation:** the boot parameters used on the IPC are in
  `reference/kernel/systemd-boot-entry.conf`:
  `isolcpus=5-N nohz_full=5,6,7 rcu_nocbs=5-N irqaffinity=0-4 housekeeping=0-4 intel_iommu=on iommu=pt`.
  Adjust the core numbers for your CPU and do not copy `root=PARTUUID=…`.
- After rebooting, `uname -v` should contain `PREEMPT_RT`.

### Rebuilding the reference kernel (untested)

- From the prepared tree: `tar --zstd -xf linux-source-…-prepared.tar.zst`, then
  `make -j"$(nproc)" bindeb-pkg`. The `.config` is already there.
- From the source package: `dpkg-source -x linux-upstream_6.15.9-224362-a50797864f54-1.dsc`,
  then `dpkg-buildpackage -b -us -uc`.

## Repository layout

| Path | Contents |
|---|---|
| `/` | EtherLab EtherCAT master source with the igb port |
| `reference/kernel/` | Kernel `.config`, boot command line, systemd-boot entry, `os-release`, `uname` |
| `reference/ethercat/` | `configure` options, `sysconfig-ethercat`, `ethercat.conf`, module `vermagic` |
| `reference/scripts/` | `ethercat_init.sh` (unbind igb and start the master) and `tune_cpu7.sh` (IRQ and kthread isolation) |
| `reference/SHA256SUMS` | Checksums of the release assets |

## License

Same as upstream: the master and the device drivers are GPL-2.0, and the userspace
library is LGPL-2.1. See [`COPYING`](COPYING) and [`COPYING.LESSER`](COPYING.LESSER).
