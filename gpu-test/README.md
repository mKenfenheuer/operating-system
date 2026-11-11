# Home Assistant OS 19.0.dev0 – GPU-Testimages

Testbuilds der Branches für GPU-Unterstützung. Nicht für den Produktivbetrieb.

## Varianten

| Datei | Einsatz | GPU |
| --- | --- | --- |
| `haos_generic-x86-64-19.0.dev0-gpu-amdgpu.img.xz` | echte Hardware | AMD (amdgpu, ROCm/KFD mit SVM), Intel iGPU/Arc (i915/xe), Intel NPU |
| `haos_generic-x86-64-19.0.dev0-gpu-nvidia.img.xz` | echte Hardware | wie amdgpu, zusätzlich NVIDIA Turing und neuer (GTX 16xx, RTX 20xx und neuer), Treiber 615 |
| `haos_generic-x86-64-19.0.dev0-gpu-nvidia-legacy.img.xz` | echte Hardware | wie amdgpu, zusätzlich NVIDIA Maxwell, Pascal, Volta (z. B. GTX 1060, Tesla P40), Treiber 580 |
| `haos_ova-19.0.dev0-gpu-amdgpu.qcow2.xz` | VM (Proxmox, KVM) | AMD (amdgpu, ROCm/KFD ohne SVM), Intel per Passthrough |
| `haos_ova-19.0.dev0-gpu-nvidia.qcow2.xz` | VM | wie amdgpu, zusätzlich NVIDIA Turing und neuer |
| `haos_ova-19.0.dev0-gpu-nvidia-legacy.qcow2.xz` | VM | wie amdgpu, zusätzlich NVIDIA Maxwell bis Volta |

AMD und Intel brauchen keine Erweiterung, die Treiber stecken im Kernel. Die NVIDIA-Varianten
sind die OS-Varianten `nvidia` und `nvidia-legacy`: gleiches Root-Dateisystem, die
Treibererweiterung liegt unter `/mnt/data/supervisor/extensions/<version>/`. Die
Update-Bundles der Varianten (`haos_<board>-<variante>-<version>.raucb`) bringen die
Erweiterung mit, ein Wechsel geht mit `POST /os/update` und `{"variant": "nvidia"}`
(oder `null` für das OS ohne NVIDIA).

Alle Varianten enthalten:

- Supervisor-Testbuild (`9999.09.9.dev9999`): `video: true` gibt Apps alle GPU-Geräte,
  `GET /hardware/gpu`, OS-Varianten in `/os/info` und `/os/update`
- OS Agent 1.15.0 mit `io.hass.os.GPU` (NVIDIA, AMD, Intel)
- Home Assistant Core dev mit GPU-Karte auf der Hardware-Seite und GPU-Sensoren
  (Geräte unter „Home Assistant Host“, Sensoren standardmäßig deaktiviert). Core lädt der
  Supervisor beim ersten Start aus der GitHub Container Registry, der erste Start braucht
  deshalb Internet und einige Minuten.

Der Testbuild des Supervisors meldet sich als Dev-Version und aktualisiert sich deshalb nicht
selbst. Ein OS-Update über die normale Update-Funktion würde die Testbuilds ersetzen.

## Installation

**Echte Hardware** Image entpacken und auf die Zielplatte schreiben, z. B.:

```sh
xz -dc haos_generic-x86-64-19.0.dev0-gpu-nvidia.img.xz | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress
```

**Proxmox** VM mit q35, OVMF (UEFI, ohne vorinstallierte Schlüssel) und PCI-Passthrough der GPU
(`pcie=1`) anlegen und das Image importieren:

```sh
xz -d haos_ova-19.0.dev0-gpu-amdgpu.qcow2.xz
qm create 200 --name haos-gpu --machine q35 --bios ovmf --cpu host --cores 4 --memory 8192 \
  --balloon 0 --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-single --ostype l26 \
  --efidisk0 local:1,efitype=4m,pre-enrolled-keys=0
qm importdisk 200 haos_ova-19.0.dev0-gpu-amdgpu.qcow2 local --format raw
qm set 200 --scsi0 local:200/vm-200-disk-1.raw,ssd=1,discard=on --boot order=scsi0 \
  --hostpci0 <mapping oder PCI-Adresse>,pcie=1
qm start 200
```

## GPU in einer App nutzen

In der `config.yaml` der App `gpu: true` setzen. Die App erhält dann `/dev/dri`, `/dev/kfd` und
`/dev/accel`. NVIDIA-GPUs kommen über CDI, Docker bindet dabei die Gerätedateien und die
Treiberbibliotheken des Hosts (`libcuda.so.1`, `nvidia-smi`) ein. Das App-Image muss auf glibc
basieren (z. B. Debian oder Ubuntu, nicht Alpine). ROCm, Mesa oder oneAPI bringt das App-Image
selbst mit.

## Prüfen

- Hardware-Seite: Einstellungen > System > Hardware (nach einem Update des Frontends die Seite
  hart neu laden)
- `curl -s -H "Authorization: Bearer $SUPERVISOR_TOKEN" http://supervisor/hardware/gpu` aus
  einer App mit `hassio_api`
- Auf dem Host (Debug-SSH, Port 22222): `systemd-sysext status`, `systemctl status haos-nvidia`,
  `nvidia-smi`
