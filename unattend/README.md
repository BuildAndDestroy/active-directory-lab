# Windows setup on KVM

virt-install uses a virtio disk. At the Windows "Where do you want to install?" screen:

1. Load driver → the second CD-ROM (virtio-win).
2. Pick `vioscsi` or `viostor` for your Windows version (amd64).
3. Optionally load `NetKVM` after first boot if the NIC is missing.

Then:

- Hostname from [inventory.yaml](../inventory.yaml) (DC-CORP, DC-CORP2, …).
- Set the local Administrator password to the value in `creds` / `00-creds.ps1`.
- After first boot, run `00-set-static-ip.ps1` then the role script for that VM.
- Enable the QEMU guest agent if virtio-win installed it.

Win11 needs TPM/UEFI; this lab targets Win10 for the workstation.

Fully unattended XML is edition-specific (eval vs retail). Prefer the GUI plus the PowerShell scripts in `scripts/windows/`.
