#!/bin/bash

MY_OPTIONS="+pcid,+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check"
ALLOCATED_RAM="6144" # MiB
CPU="host"
REPO_PATH="."
OVMF_DIR="OVMF"
I915_OVMF_DIR="i915ovmf"

args=(
  -enable-kvm
  -m "$ALLOCATED_RAM"
  -cpu "$CPU",kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,"$MY_OPTIONS"
  -machine q35
  -smp $(nproc)
  -vga none
  -nographic
  -device vfio-pci,host=0000:00:02.0,id=hostdev0,bus=pcie.0,addr=0x2,romfile="$REPO_PATH/$I915_OVMF_DIR/8086-0406-vbios.rom"
  -device ich9-intel-hda -device hda-duplex
  -device ich9-ahci,id=sata
  -drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file="$REPO_PATH/OpenCore-Catalina/OpenCore.qcow2"
  -device ide-hd,bus=sata.2,drive=OpenCoreBoot
  -device ide-hd,bus=sata.3,drive=InstallMedia
  -drive id=InstallMedia,if=none,file="$REPO_PATH/BaseSystem.img",format=raw
  -drive id=MacHDD,if=none,file="$REPO_PATH/mac_hdd_ng.img",format=qcow2
  -device ide-hd,bus=sata.4,drive=MacHDD
  -netdev user,id=net0 -device vmxnet3,netdev=net0,id=net0,mac=52:54:00:c9:18:27
  -usb
  -fw_cfg name=opt/igd-opregion,file="$REPO_PATH/$I915_OVMF_DIR/opregion.bin"
  -fw_cfg name=opt/igd-bdsm-size,file="$REPO_PATH/$I915_OVMF_DIR/bdsmSize.bin"
  -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"
  -drive if=pflash,format=raw,readonly=on,file="$REPO_PATH/$OVMF_DIR/OVMF_CODE.fd"
  -drive if=pflash,format=raw,file="$REPO_PATH/$OVMF_DIR/OVMF_VARS-1024x768.fd"
  -smbios type=2
)

qemu-system-x86_64 "${args[@]}"
