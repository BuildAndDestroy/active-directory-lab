# active-directory-lab

Portable QEMU/KVM Active Directory lab for local study: **three forests** (`corp.lab`, `partner.lab`, `foothold.lab`), replica DC, member server, Enterprise CA, Windows 10 workstation, dual-homed pivot, vulnerable foothold web server, Kali on an isolated foothold subnet.

Isolated study network only. Do not bridge this lab onto a network you do not control.

This repo provisions **infrastructure**. It does not include attack procedures.

## Challenge shape

Start on the **foothold** (`192.168.58.0/24`) with Kali. **`foothold.lab`** is its own forest (DC-FOOTHOLD on `.58`) with **SRV-FOOTHOLD** (vulnerable IIS) and **JUMP-CORP** (dual-homed pivot). **`corp.lab`** (Domain Admin prize) lives on `192.168.57.0/24` and is not routed from the foothold. Practice path: exploit foothold web → `foothold.lab` foothold → pivot via JUMP → Domain Admin on `corp.lab` (bidirectional forest trust exists for escalation practice).

## Topology

```mermaid
flowchart TB
  subgraph footholdNet["ad-lab-foothold · isolated · 192.168.58.0/24 · start here"]
    gw58["Host gateway 192.168.58.1"]
    kali["kali-ad · .100"]
    subgraph fhForest["foothold.lab"]
      dcfh["DC-FOOTHOLD · .15"]
      srvfh["SRV-FOOTHOLD · .20 · vuln IIS"]
      jump58["JUMP-CORP eth1 · .10"]
      dcfh --- srvfh
      dcfh --- jump58
    end
    kali --- srvfh
  end

  subgraph corpNet["ad-lab · NAT · 192.168.57.0/24 · corp DA prize"]
    gw57["Host gateway 192.168.57.1"]
    jump57["JUMP-CORP eth0 · .60 · pivot NIC only"]

    subgraph corp["corp.lab"]
      dc1["DC-CORP · .10"]
      dc2["DC-CORP2 · .11"]
      srv["SRV-CORP · .30"]
      ca["CA-CORP · .40"]
      w10["WIN10-CORP · .50"]
      dc1 --- dc2
      dc1 --- srv
      dc1 --- ca
      dc1 --- w10
      jump57 --- dc1
    end

    subgraph partner["partner.lab"]
      dcp["DC-PARTNER · .20"]
    end

    trustPartner{{"corp ↔ partner trust"}}
    trustFh{{"corp ↔ foothold trust"}}
    dc1 --- trustPartner
    trustPartner --- dcp
    dc1 --- trustFh
  end

  kali -.->|"no route without pivot"| corpNet
  jump58 -->|"same VM · IP forwarding OFF"| jump57
  trustFh -.-> dcfh
```

| Guest | Hostname | Role | Network | IP | RAM |
|-------|----------|------|---------|-----|-----|
| dc-corp | DC-CORP | `corp.lab` forest root, FSMO, DNS | `ad-lab` | 192.168.57.10 | 4 GB |
| dc-corp2 | DC-CORP2 | replica DC, DNS, GC | `ad-lab` | 192.168.57.11 | 4 GB |
| dc-partner | DC-PARTNER | `partner.lab` forest root, DNS | `ad-lab` | 192.168.57.20 | 4 GB |
| srv-corp | SRV-CORP | member + `\\SRV-CORP\Share` | `ad-lab` | 192.168.57.30 | 4 GB |
| ca-corp | CA-CORP | Enterprise CA (not a DC) | `ad-lab` | 192.168.57.40 | 8 GB |
| win10-corp | WIN10-CORP | workstation | `ad-lab` | 192.168.57.50 | 4 GB |
| jump-corp | JUMP-CORP | dual-homed pivot, **`foothold.lab`** member | both | 192.168.57.60 + 192.168.58.10 | 4 GB |
| dc-foothold | DC-FOOTHOLD | **`foothold.lab`** forest root, DNS | `ad-lab-foothold` | 192.168.58.15 | 4 GB |
| srv-foothold | SRV-FOOTHOLD | **`foothold.lab`** member, vulnerable IIS | `ad-lab-foothold` | 192.168.58.20 | 4 GB |
| kali-ad | kali | analyst (start here) | `ad-lab-foothold` | 192.168.58.100 | 4 GB |

**Networks**

| Network | Mode | CIDR | Gateway | Who |
|---------|------|------|---------|-----|
| `ad-lab` | NAT | 192.168.57.0/24 | 192.168.57.1 | All DCs, members, CA, WIN10; JUMP eth0 |
| `ad-lab-foothold` | isolated (no NAT, no route to `.57`) | 192.168.58.0/24 | 192.168.58.1 | `foothold.lab` (DC, SRV, JUMP eth1), Kali |

DHCP on both nets is **.128–.250** (install / script download only). After setup, use the **static** IPs above.

**JUMP-CORP:** member of **`foothold.lab`** (AD/DNS on eth1 → DC-FOOTHOLD `.58.15`). eth1 → `.58.10` (metric 10). eth0 → `.57.60`, gw `.57.1`, **no DNS** (metric 200 — corp pivot path only). IP forwarding stays **off**.

Domains: `corp.lab`, `partner.lab`, `foothold.lab` — none collide with OffSec `corp.com`.

### Existing Kali on ad-lab

If `kali-ad` was created on `ad-lab` before this change, move it to the foothold (VM shut off):

```bash
./scripts/host/create-network.sh   # ensures ad-lab-foothold exists
virsh detach-interface kali-ad network --current
virsh attach-interface kali-ad network ad-lab-foothold --model virtio --config
# then start the guest and set static 192.168.58.100
```

Or destroy the domain definition (keep the disk) and re-run `./scripts/host/virt-install-guest.sh kali-ad`.

## Host prerequisites

- `qemu-kvm`, `libvirt`, `virt-install`, `virt-manager`; your user in `libvirt` / `kvm`
- Windows Server **Standard**, **Desktop Experience** eval ISO. Do **not** use Hyper-V Server / SERVERHYPERCORE
- Windows 10 ISO
- Optional [virtio-win](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/) ISO (without it, guests use SATA + e1000)
- Optional Kali ISO
- Disks live under `/var/lib/libvirt/images/ad-kvm-lab` (never under `$HOME`). `create-disks.sh` creates that directory with sudo if needed.

Copy config and lab passwords:

```bash
cp config.env.example config.env
cp creds.example creds
cp scripts/windows/00-creds.ps1.example scripts/windows/00-creds.ps1
# edit config.env ISO paths
```

## Host: network, disks, VMs

Disks are **thin qcow2** (`preallocation=off`, 60G virtual, almost no space until the guest writes). `ls -lh` can still show 60G; `du -h` is what is used on disk.

```bash
chmod +x scripts/host/*.sh
./scripts/host/create-network.sh
./scripts/host/create-disks.sh
./scripts/host/virt-install-guest.sh dc-corp
# then dc-corp2, dc-partner, srv-corp, ca-corp, win10-corp, dc-foothold, jump-corp, srv-foothold, kali-ad
```

Finish Windows setup in virt-manager. Load virtio drivers from the second CD — see [unattend/README.md](unattend/README.md). Hostname and IP must match the table. Local Administrator password must match `00-creds.ps1`.

Snapshot after each major role (`virsh snapshot-create-as <guest> baseline`).

Kerberos: keep Windows clocks within ~5 minutes of the DCs (host NTP/chrony).

## Guest: download scripts, then run them

On the **Linux hypervisor**:

```bash
chmod +x scripts/host/*.sh
./scripts/host/serve-windows-scripts.sh
```

On each **Windows VM** (elevated PowerShell). Corp guests use `.57.1`; JUMP (and any foothold Windows guest) can use `.58.1` while on DHCP:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
# Corp (.57) guests:
irm http://192.168.57.1:8080/00-download.ps1 | iex
# Foothold (.58) guests (DC-FOOTHOLD, SRV-FOOTHOLD, JUMP):
# irm http://192.168.58.1:8080/00-download.ps1 | iex
# 00-download.ps1 auto-picks the reachable gateway for the rest of the files.
```

That writes everything to `C:\Lab`. Then set **this guest’s** hostname and static IP (`-Role` must match the VM, not always `DC-CORP`):

```powershell
cd C:\Lab
.\00-bootstrap.ps1 -Role DC-CORP      # first DC only
.\00-bootstrap.ps1 -Role DC-CORP2
.\00-bootstrap.ps1 -Role DC-PARTNER
.\00-bootstrap.ps1 -Role SRV-CORP
.\00-bootstrap.ps1 -Role CA-CORP
.\00-bootstrap.ps1 -Role WIN10-CORP
.\00-bootstrap.ps1 -Role JUMP-CORP
.\00-bootstrap.ps1 -Role DC-FOOTHOLD
.\00-bootstrap.ps1 -Role SRV-FOOTHOLD
```

Valid roles: `DC-CORP`, `DC-CORP2`, `DC-PARTNER`, `SRV-CORP`, `CA-CORP`, `WIN10-CORP`, `JUMP-CORP`, `DC-FOOTHOLD`, `SRV-FOOTHOLD`. After reboot, run only the numbered script for **that** host. Defaults live in `00-lab-config.ps1` (optional override: `00-creds.ps1`). Numbered scripts refuse to run on the wrong hostname.

1. **DC-CORP:** `.\01-promote-forest-corp.ps1` # Check `dcdiag` is clean enough for a lab.
2. **DC-CORP2:** `.\02-promote-replica-corp.ps1` (joins, reboots, run again to promote) then `.\02b-verify-replication.ps1`
3. **DC-PARTNER:** `.\03-promote-forest-partner.ps1`
4. **Forest trust + DNS forwarders** (two VMs, two scripts — do **not** run `04` on both):
   - **On DC-CORP only:** `.\04-dns-forwarders-and-trust.ps1`  
     Adds a forwarder for `partner.lab` → `192.168.57.20` and creates the bidirectional forest trust.
   - **On DC-PARTNER only:** `.\04b-partner-forwarder.ps1`  
     Adds a forwarder for `corp.lab` → `192.168.57.10` / `.11`.  
     Verify on either DC: `nltest /domain_trusts` and `nslookup dc-corp.corp.lab` from DC-PARTNER.
5. **DC-CORP:** `.\05-domain-objects-corp.ps1`
6. **DC-PARTNER:** `.\06-domain-objects-partner.ps1`
7. **SRV-CORP:** `.\10-join-domain.ps1` then `.\07-member-share.ps1`
8. **CA-CORP:** `.\10-join-domain.ps1` then log on as **`CORP\Administrator`** (not local `Administrator`) and run `.\08-install-adcs.ps1`
9. **WIN10-CORP:** `.\10-join-domain.ps1` then `.\09-win10-local-admin.ps1`
10. **DC-FOOTHOLD:** `.\13-promote-forest-foothold.ps1` then `.\14-domain-objects-foothold.ps1`
11. **JUMP-CORP** (after DC-FOOTHOLD is up): `.\11-join-jump.ps1`  
    Joins **`foothold.lab`** on the foothold NIC; corp NIC is pivot-only. Run twice if it reboots mid-join.
12. **SRV-FOOTHOLD:** `.\12-setup-foothold-web.ps1` (reboots after join; run again for IIS)
13. **Forest trust corp ↔ foothold** (requires temporary JUMP routing):
    - **JUMP-CORP:** `.\11c-jump-setup-routing.ps1 -Mode Enable`
    - **DC-CORP:** `.\04c-corp-foothold-trust.ps1`
    - **DC-FOOTHOLD:** `.\04d-foothold-corp-forwarder.ps1`
    - **JUMP-CORP:** `.\11c-jump-setup-routing.ps1 -Mode Disable`
    - Vulnerable app: `http://192.168.58.20/default.aspx?host=127.0.0.1` (lab-only command injection)
14. **Kali:** static `192.168.58.100` on foothold only (no NIC on `ad-lab`)

Microsoft: [AD DS](https://learn.microsoft.com/windows-server/identity/ad-ds/deploy/install-active-directory-domain-services--level-100-), [replica DC](https://learn.microsoft.com/windows-server/identity/ad-ds/deploy/install-a-replica-windows-server-2012-domain-controller-in-an-existing-domain--level-200-), [AD CS](https://learn.microsoft.com/windows-server/identity/ad-cs/active-directory-certificate-services-overview), [conditional forwarders](https://learn.microsoft.com/windows-server/networking/dns/deploy/create-a-conditional-forwarder).

## Lab directory objects

- OUs: `CorpUsers`, `CorpGroups`, `CorpServers`, `CorpWorkstations`
- Nested groups: `CorpStaff` → `ITStaff` → `Helpdesk`
- Users: `jdoe`, `hadmin`, `svc_web` (SPN `HTTP/srv-corp.corp.lab`)
- Share: `\\SRV-CORP\Share`
- `CORP\jdoe` in local Administrators on WIN10-CORP
- partner.lab: `puser`, `padmin` (padmin in Domain Admins)
- foothold.lab: `fuser`, `fadmin` (fadmin in Domain Admins)
- JUMP-CORP: dual-homed member of **`foothold.lab`** (no IP forwarding after setup)
- SRV-FOOTHOLD: **`foothold.lab`** member; IIS ping utility with deliberate command injection (`host=` parameter)
- Bidirectional forest trusts: corp ↔ partner, corp ↔ foothold

Passwords are in `creds.example` (weak, lab-only).

## Layout

```
.
  README.md
  inventory.yaml
  creds.example
  config.env.example
  network/ad-lab.xml
  network/ad-lab-foothold.xml
  scripts/host/
  scripts/windows/
  unattend/README.md
```
