#!/bin/bash


# apt install curl

# obviously change this per your needs
VMID=9001
STOR=local-lvm
VER=20240102-1614
URL_PATH=https://mirrors.ustc.edu.cn/debian-cdimage/cloud/bookworm/$VER/
IMG=debian-12-genericcloud-amd64-$VER.qcow2

curl -L -o $IMG -C - $URL_PATH$IMG
# https://pve.proxmox.com/wiki/Cloud-Init_Support
# https://pve.proxmox.com/wiki/Qemu/KVM_Virtual_Machines
qm create $VMID --cores 8 --cpu cputype=host --memory 16384 --net0 virtio,bridge=vmbr0 --ostype l26 --serial0 socket --vga serial0
qm importdisk $VMID $IMG $STOR
qm set $VMID --scsihw virtio-scsi-single --scsi0 $STOR:vm-$VMID-disk-0,discard=on,iothread=true
qm set $VMID --ide2 $STOR:cloudinit
qm set $VMID --boot c --bootdisk scsi0

qm template $VMID
