<#
.SYNOPSIS
Создаёт одну или несколько виртуальных машин VirtualBox из OVA-образа Ubuntu
с использованием cloud-init ISO и NatNetwork.

.DESCRIPTION
Скрипт автоматизирует создание виртуальных машин VirtualBox на базе
официального OVA-образа Ubuntu Server (cloud image).

Для каждой VM:
- импортируется OVA
- настраиваются CPU, RAM и размер диска
- монтируется cloud-init ISO (NoCloud)
- настраивается сеть NatNetwork
- при необходимости создаётся NatNetwork
- включается EFI
- удаляется floppy controller

Скрипт предназначен для локальной инфраструктуры, лабораторных стендов,
Ansible-окружений и DevOps-экспериментов.

.PARAMETER VmNames
Список имён виртуальных машин, разделённых запятыми.

Ограничения:
- только латиница
- цифры
- символ '-'
- без пробелов

Пример:
max-ansible-1,max-ansible-2

.PARAMETER OvaPath
Полный путь к OVA-файлу с образом Ubuntu Server (cloud image).

Пример:
D:\VirtualBox VMs\noble-server-cloudimg-amd64.ova

.PARAMETER IsoDir
Каталог, в котором лежат cloud-init ISO-образы.
Для каждой VM ожидается файл:
<VMNAME>.iso

Пример:
D:\VirtualBox VMs\isos

.PARAMETER NatNetwork
Имя NatNetwork в VirtualBox.

Если сеть с таким именем не существует — она будет создана автоматически.

.PARAMETER NatNetworkPrefix
IPv4-префикс для NatNetwork в формате CIDR.

Пример:
10.0.2.0/24

DHCP и IPv6 будут отключены.

.PARAMETER CpuCount
Количество виртуальных CPU для каждой VM.

Пример:
4

.PARAMETER MemoryMb
Объём оперативной памяти для VM в мегабайтах.

Пример:
4096

.PARAMETER DiskSizeMb
Размер виртуального диска в мегабайтах.
Диск увеличивается после импорта OVA.

Пример:
30720  (30 GB)

.EXAMPLE
Создать две VM с общими параметрами:

.\create-vms.ps1 `
  -VmNames max-ansible-1,max-ansible-2 `
  -OvaPath "D:\VirtualBox VMs\noble-server-cloudimg-amd64.ova" `
  -IsoDir "D:\VirtualBox VMs\isos" `
  -NatNetwork ansible-network `
  -NatNetworkPrefix "10.0.2.0/24" `
  -CpuCount 4 `
  -MemoryMb 4096 `
  -DiskSizeMb 30720

.NOTES
Требования:
- Windows
- VirtualBox установлен и VBoxManage доступен в PATH
- PowerShell 5.1+ или PowerShell 7+
- cloud-init ISO (NoCloud) подготовлены заранее

Скрипт не запускает VM автоматически.
Первый запуск VM должен быть выполнен вручную.

.AUTHOR
Local DevOps Automation Script

#>

param (
    [Parameter(Mandatory = $true)]
    [string]$VmNames,

    [Parameter(Mandatory = $true)]
    [string]$OvaPath,

    [Parameter(Mandatory = $true)]
    [string]$IsoDir,

    [Parameter(Mandatory = $true)]
    [string]$NatNetwork,

    [Parameter(Mandatory = $true)]
    [string]$NatNetworkPrefix,

    [Parameter(Mandatory = $true)]
    [int]$CpuCount,

    [Parameter(Mandatory = $true)]
    [int]$MemoryMb,

    [Parameter(Mandatory = $true)]
    [int]$DiskSizeMb
)

# ===== КОНСТАНТЫ =====
$NicType = "82545EM"

# ===== ПРОВЕРКИ =====
if (-not (Test-Path $OvaPath)) {
    Write-Error "OVA файл не найден: $OvaPath"
    exit 1
}

if (-not (Test-Path $IsoDir)) {
    Write-Error "Каталог с ISO не найден: $IsoDir"
    exit 1
}

# ===== ПРОВЕРКА / СОЗДАНИЕ NAT NETWORK =====
$ExistingNat = VBoxManage natnetwork list |
    Select-String -Pattern "Name:\s+$NatNetwork"

if (-not $ExistingNat) {

    Write-Host "NatNetwork '$NatNetwork' не найден. Создаю..." -ForegroundColor Yellow

    VBoxManage natnetwork add `
        --netname $NatNetwork `
        --network $NatNetworkPrefix `
        --enable `
        --dhcp off `
        --ipv6 off

} else {
    Write-Host "NatNetwork '$NatNetwork' уже существует" -ForegroundColor Green
}

# ===== РАЗБОР ИМЁН VM =====
$Names = $VmNames.Split(",") | ForEach-Object { $_.Trim() }

foreach ($Name in $Names) {

    if ($Name -notmatch '^[a-zA-Z0-9\-]+$') {
        Write-Error "Недопустимое имя VM: $Name"
        continue
    }

    $IsoPath = Join-Path $IsoDir "$Name.iso"

    if (-not (Test-Path $IsoPath)) {
        Write-Error "ISO не найден: $IsoPath"
        continue
    }

    Write-Host "`n=== Создаю VM: $Name ===" -ForegroundColor Cyan

    # --- Импорт OVA ---
    VBoxManage import "$OvaPath" `
        --vsys 0 `
        --vmname $Name `
        --cpus $CpuCount `
        --memory $MemoryMb

    # --- Найти VMDK ---
    $DiskPath = VBoxManage showvminfo $Name |
        Select-String -Pattern '\.vmdk' |
        ForEach-Object {
            ($_ -split ':', 2)[1].Trim()
        }

    if (-not $DiskPath) {
        Write-Error "Не удалось найти VMDK для $Name"
        continue
    }

    # --- Увеличить диск ---
    VBoxManage modifymedium disk "$DiskPath" --resize $DiskSizeMb

    # --- Подключить cloud-init ISO ---
    VBoxManage storageattach $Name `
        --storagectl "IDE" `
        --port 0 `
        --device 0 `
        --type dvddrive `
        --medium "$IsoPath"

    # --- Сеть ---
    VBoxManage modifyvm $Name `
        --nic1 natnetwork `
        --nat-network1 $NatNetwork `
        --nictype1 $NicType

    # --- Удалить floppy ---
    VBoxManage storagectl $Name --name "Floppy Controller" --remove 2>$null

    Write-Host "VM $Name успешно создана" -ForegroundColor Green
}

Write-Host "`nВсе виртуальные машины созданы." -ForegroundColor Yellow