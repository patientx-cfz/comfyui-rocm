import subprocess
import sys
import os
import re
import csv
import io

def log(*args, **kwargs):
    """All diagnostics go to stderr so stdout stays clean for the gfx code
    that install.bat's `for /f` captures."""
    print(*args, file=sys.stderr, **kwargs)

# PCI device IDs (Win32_VideoController PNPDeviceID, "DEV_xxxx") for chips
# whose Windows-reported Name is a generic string like "AMD Radeon(TM)
# Graphics" instead of the marketing name - the substring table below can
# never match these. Checked BEFORE the name-based table.
# Source: github.com/pciutils/pciids pci.ids, cross-checked against AMD
# ROCm/LLVM gfx-target docs for the codename -> gfx mapping. One device ID
# can cover several marketing names (binned/fused SKUs of the same die).
# Format: dev_id (lowercase hex, no "0x") -> (gfx_code, label, supported)
PCI_DEV_TO_GFX = {
    # RDNA4 - Navi44/Navi48
    '7590': ('gfx1200', 'Navi 44 (RX 9060 XT)', True),
    '7550': ('gfx1201', 'Navi 48 (RX 9070/9070 XT/9070 GRE)', True),
    '7551': ('gfx1201', 'Navi 48 (Radeon AI PRO R9700)', True),
    '7580': ('gfx1201', 'Navi 48 (RX 9070 XT)', True),
    '7581': ('gfx1201', 'Navi 48 (RX 9070)', True),
    '7591': ('gfx1201', 'Navi 44 (RX 9060 XT)', True),
    '75a1': ('gfx1201', 'Navi 48 (RX 9070 GRE)', True),
    '75b0': ('gfx1201', 'Navi 48 (RX 9070 XT)', True),

    # RDNA3.5 - Strix / Strix Halo / Krackan Point
    '150e': ('gfx1150', 'Strix (880M/890M)', True),
    '1586': ('gfx1151', 'Strix Halo (8050S/8060S)', True),
    '1114': ('gfx1152', 'Krackan Point (840M/860M)', True),
    '1590': ('gfx1150', 'Strix Point (880M)', True),
    '1591': ('gfx1150', 'Strix Point (890M)', True),
    '15d0': ('gfx1152', 'Krackan Point (860M)', True),

    # RDNA3 - Navi31/32/33, Phoenix
    '7448': ('gfx1100', 'Navi 31 (Pro W7900)', True),
    '7449': ('gfx1100', 'Navi 31 (Pro W7800 48GB)', True),
    '744a': ('gfx1100', 'Navi 31 (Pro W7900 Dual Slot)', True),
    '744b': ('gfx1100', 'Navi 31 (Pro W7900D)', True),
    '744c': ('gfx1100', 'Navi 31 (RX 7900 XT/XTX/GRE/7900M)', True),
    '745e': ('gfx1100', 'Navi 31 (Pro W7800)', True),
    '7460': ('gfx1101', 'Navi 32 (Pro V710)', True),
    '7461': ('gfx1101', 'Navi 32 (Pro V710)', True),
    '7470': ('gfx1101', 'Navi 32 (Pro W7700)', True),
    '747e': ('gfx1101', 'Navi 32 (RX 7700 XT/7800 XT)', True),
    '7480': ('gfx1102', 'Navi 33 (RX 7600 series/Pro W7600)', True),
    '7481': ('gfx1102', 'Navi 33', True),
    '7483': ('gfx1102', 'Navi 33 (RX 7600M/7600M XT)', True),
    '7487': ('gfx1102', 'Navi 33', True),
    '7489': ('gfx1102', 'Navi 33 (Pro W7500)', True),
    '748b': ('gfx1102', 'Navi 33', True),
    '7499': ('gfx1102', 'Navi 33 (RX 7400/7300/Pro W7400)', True),
    '749f': ('gfx1102', 'Navi 33 (RX 7500)', True),
    '15bf': ('gfx1103', 'Phoenix1 (780M/760M/740M)', True),
    '15c8': ('gfx1103', 'Phoenix2 (780M/760M/740M)', True),
    '164f': ('gfx1103', 'Phoenix (780M/760M/740M)', True),

    # RDNA2 - Navi21/22/23/24, Rembrandt, Mendocino
    '73a1': ('gfx1030', 'Navi 21 (Pro V620)', True),
    '73a2': ('gfx1030', 'Navi 21 (Pro W6900X)', True),
    '73a3': ('gfx1030', 'Navi 21 (Pro W6800)', True),
    '73a5': ('gfx1030', 'Navi 21 (RX 6950 XT)', True),
    '73ab': ('gfx1030', 'Navi 21 (Pro W6800X/W6800X Duo)', True),
    '73ae': ('gfx1030', 'Navi 21 (Pro V620 MxGPU)', True),
    '73af': ('gfx1030', 'Navi 21 (RX 6900 XT)', True),
    '73bf': ('gfx1030', 'Navi 21 (RX 6800/6800 XT/6900 XT)', True),
    '73c3': ('gfx1031', 'Navi 22', True),
    '73ce': ('gfx1031', 'Navi 22 (SRIOV MxGPU)', True),
    '73df': ('gfx1031', 'Navi 22 (RX 6700/6750 XT/6800M/6850M XT)', True),
    '73e0': ('gfx1032', 'Navi 23', True),
    '73e1': ('gfx1032', 'Navi 23 (Pro W6600M)', True),
    '73e3': ('gfx1032', 'Navi 23 (Pro W6600)', True),
    '73ef': ('gfx1032', 'Navi 23 (RX 6650 XT/6700S/6800S)', True),
    '73ff': ('gfx1032', 'Navi 23 (RX 6600/6600 XT/6600M)', True),
    '73e2': ('gfx1032', 'Navi 23 (RX 6600 OEM)', True),
    '73f0': ('gfx1032', 'Navi 23 (RX 6650 XT OEM)', True),
    '163f': ('gfx1033', 'Van Gogh', True),
    '7421': ('gfx1034', 'Navi 24 (Pro W6500M)', True),
    '7422': ('gfx1034', 'Navi 24 (Pro W6400)', True),
    '7423': ('gfx1034', 'Navi 24 (Pro W6300/W6300M)', True),
    '7424': ('gfx1034', 'Navi 24 (RX 6300)', True),
    '743f': ('gfx1034', 'Navi 24 (RX 6400/6500 XT/6500M)', True),
    '1681': ('gfx1035', 'Rembrandt (680M/660M)', True),
    '1506': ('gfx1036', 'Mendocino (610M)', True),

    # RDNA1 - Navi10/12/14
    '7310': ('gfx1010', 'Navi 10 (Pro W5700X)', True),
    '7312': ('gfx1010', 'Navi 10 (Pro W5700)', True),
    '7319': ('gfx1010', 'Navi 10 (Pro 5700 XT)', True),
    '731b': ('gfx1010', 'Navi 10 (Pro 5700)', True),
    '731f': ('gfx1010', 'Navi 10 (RX 5600/5700 series)', True),
    '7360': ('gfx1011', 'Navi 12 (Pro 5600M/V520/BC-160)', True),
    '7362': ('gfx1011', 'Navi 12 (Pro V520/V540)', True),
    '7340': ('gfx1012', 'Navi 14 (RX 5500/5500M/Pro 5300)', True),
    '7341': ('gfx1012', 'Navi 14 (Pro W5500)', True),
    '7347': ('gfx1012', 'Navi 14 (Pro W5500M)', True),
    '734f': ('gfx1012', 'Navi 14 (Pro W5300M)', True),

    # Data Center / Enterprise
    '74a0': ('gfx942', 'Aqua Vanjaram (Instinct MI300A)', True),
    '74a1': ('gfx942', 'Aqua Vanjaram (Instinct MI300X)', True),
    '74a2': ('gfx942', 'Aqua Vanjaram (Instinct MI308X)', True),
    '74a5': ('gfx942', 'Aqua Vanjaram (Instinct MI325X)', True),
    '74a9': ('gfx942', 'Aqua Vanjaram (Instinct MI300X HF)', True),
    '74b5': ('gfx942', 'Aqua Vanjaram (Instinct MI300X VF)', True),
    '74b9': ('gfx942', 'Aqua Vanjaram (Instinct MI325X VF)', True),
    '74bd': ('gfx942', 'Aqua Vanjaram (Instinct MI300X HF)', True),
    '75a0': ('gfx950', 'Aqua Vanjaram (Instinct MI350X)', True),
    '75a3': ('gfx950', 'Aqua Vanjaram (Instinct MI355X)', True),

    # GCN5 / Vega
    '6860': ('gfx900', 'Vega 10 (Instinct MI25/V340/V320)', True),
    '6861': ('gfx900', 'Vega 10 (Pro WX 9100)', True),
    '6862': ('gfx900', 'Vega 10 (Pro SSG)', True),
    '6863': ('gfx900', 'Vega 10 (Vega Frontier Edition)', True),
    '6864': ('gfx900', 'Vega 10 (Pro V340/Instinct MI25x2)', True),
    '6867': ('gfx900', 'Vega 10 (Pro Vega 56)', True),
    '6868': ('gfx900', 'Vega 10 (Pro WX 8100/8200)', True),
    '6869': ('gfx900', 'Vega 10 (Pro Vega 48)', True),
    '686b': ('gfx900', 'Vega 10 (Pro Vega 64X)', True),
    '686c': ('gfx900', 'Vega 10 (Instinct MI25 MxGPU)', True),
    '687f': ('gfx900', 'Vega 10 (RX Vega 56/64)', True),
    '66a0': ('gfx906', 'Vega 20 (Pro/Instinct)', True),
    '66a1': ('gfx906', 'Vega 20 (Pro VII/Instinct MI50)', True),
    '66a3': ('gfx906', 'Vega 20 (Pro Vega II/Vega II Duo)', True),
    '66a7': ('gfx906', 'Vega 20 (Pro Vega 20)', True),
    '66af': ('gfx906', 'Vega 20 (Radeon VII)', True),
    '738c': ('gfx908', 'Arcturus (Instinct MI100)', True),
    '738e': ('gfx908', 'Arcturus (Instinct MI100)', True),
    '7408': ('gfx90a', 'Aldebaran (Instinct MI250X)', True),
    '740c': ('gfx90a', 'Aldebaran (Instinct MI250X/MI250)', True),
    '740f': ('gfx90a', 'Aldebaran (Instinct MI210)', True),
}

# Comprehensive mapping of GPU model numbers to gfx codes
# Format: (model_list, gfx_code, architecture_name, supported)
GPU_TO_GFX = [
    # RDNA4 (gfx12xx)
    (['rx 9060'], 'gfx1200', 'RDNA 4', True),
    (['rx 9070', 'r9700', 'r9600'], 'gfx1201', 'RDNA 4', True),
    (['gfx12-0'], 'gfx12-0', 'RDNA 4', True),
    
    # RDNA3.5 (gfx115x)
    (['890m', '880m'], 'gfx1150', 'Strix Point', True),
    (['8060s', '8050s', '8040s'], 'gfx1151', 'Strix Halo', True),
    (['860m', '840m', '820m'], 'gfx1152', 'Krackan Point', True),
    (['gfx1153'], 'gfx1153', 'RDNA 3.5', True),
    
    # RDNA3 (gfx110x)
    (['rx 7900', 'w7900', 'w7800'], 'gfx1100', 'RDNA 3', True),
    (['rx 7800', 'rx 7700', 'w7700'], 'gfx1101', 'RDNA 3', True),
    (['rx 7700s', 'rx 7650', 'rx 7600', 'w7600', 'w7500', 'rx 7400', 'w7400'], 'gfx1102', 'RDNA 3', True),
    (['780m', '760m', '740m'], 'gfx1103', 'RDNA 3', True),
       
    # RDNA2 (gfx103x)
    (['rx 6950', 'rx 6900', 'rx 6800', 'w6800', 'v620'], 'gfx1030', 'RDNA 2', True),
    (['rx 6750', 'rx 6700', 'rx 6800m', 'rx 6700m', 'rx 6800s', 'rx 6700s'], 'gfx1031', 'RDNA 2', True),
    (['rx 6650', 'rx 6600', 'w6600', 'rx 6650m', 'rx 6600m', 'rx 6600s'], 'gfx1032', 'RDNA 2', True),
    (['van gogh', 'amd custom apu 0405'], 'gfx1033', 'RDNA 2', True),
    (['rx 6550', 'rx 6500', 'rx 6450', 'rx 6400', 'w6500', 'w6400', 'rx 6300', 'w6300', 'rx 6500m', 'rx 6450m', 'rx 6300m', 'rx 6550m', 'rx 6550s'], 'gfx1034', 'RDNA 2', True),
    (['680m', '660m'], 'gfx1035', 'RDNA 2', True),
    (['610m'], 'gfx1036', 'RDNA 2', True),

    # RDNA1 (gfx101x)
    (['rx 5700', 'rx 5600'], 'gfx1010', 'RDNA 1', True),
    (['radeon pro v520'], 'gfx1011', 'RDNA 1 (Navi 12)', True),
    (['rx 5500'], 'gfx1012', 'RDNA 1 (Navi 14)', True),
    
    # Data Center / Enterprise GPUs
    (['radeon pro vii'], 'gfx906', 'Radeon Pro VII / Vega 20', True),
    (['mi300a', 'mi300x', 'mi325x'], 'gfx942', 'MI300/MI325', True),  # Now supported via legacy URL
    (['mi350x', 'mi355x'], 'gfx950', 'MI350/MI355', True),  # Now supported via legacy URL

    # GCN5 / Vega (gfx900/906/908/90a)
    (['rx vega', 'vega 64', 'vega 56', 'vega frontier'], 'gfx900', 'Vega 10 / GCN5', True),
    (['radeon vii', 'vega 20'], 'gfx906', 'Vega 20 / GCN5', True),
    (['instinct mi100'], 'gfx908', 'Arcturus / MI100', True),
    (['instinct mi200', 'instinct mi210', 'instinct mi250'], 'gfx90a', 'Aldebaran / MI200', True),
]

def _parse_gpu_csv(output):
    """Parse 'Name,PNPDeviceID' CSV output from either wmic or PowerShell
    into a list of {'name':, 'pnp_id':} dicts for AMD/Radeon entries."""
    amd_gpus = []
    lines = [l for l in output.splitlines() if l.strip()]
    if len(lines) < 2:
        return amd_gpus
    try:
        for row in csv.DictReader(lines):
            name = (row.get('Name') or '').strip()
            pnp_id = (row.get('PNPDeviceID') or '').strip()
            if name and ("VEN_1002" in pnp_id.upper() or "AMD" in name or "Radeon" in name):
                amd_gpus.append({'name': name, 'pnp_id': pnp_id})
    except csv.Error:
        pass
    return amd_gpus

def detect_gpu_wmic():
    try:
        result = subprocess.run(
            ['wmic', 'path', 'win32_videocontroller', 'get', 'name,pnpdeviceid', '/format:csv'],
            capture_output=True,
            text=True,
            check=False,
            timeout=10
        )
        
        if result.returncode == 0:
            return _parse_gpu_csv(result.stdout)
    except (FileNotFoundError, subprocess.TimeoutExpired, Exception):
        pass
    return []

def detect_gpu_powershell():
    try:
        # Get-CimInstance, not Get-WmiObject - the latter is gone in PowerShell 7
        ps_command = (
            "Get-CimInstance Win32_VideoController | "
            "Select-Object Name,PNPDeviceID | ConvertTo-Csv -NoTypeInformation"
        )
        result = subprocess.run(
            ['powershell', '-NoProfile', '-Command', ps_command],
            capture_output=True,
            text=True,
            check=False,
            timeout=10
        )
        
        if result.returncode == 0:
            return _parse_gpu_csv(result.stdout)
    except (FileNotFoundError, subprocess.TimeoutExpired, Exception):
        pass
    return []

def match_gpu_to_gfx(gpu):
    # PCI device ID first - survives generic/OEM Name strings
    pnp_id = gpu.get('pnp_id', '')
    m = re.search(r'DEV_([0-9A-Fa-f]{4})', pnp_id)
    if m:
        hit = PCI_DEV_TO_GFX.get(m.group(1).lower())
        if hit:
            return hit

    gpu_lower = gpu['name'].lower()
    for model_list, gfx, arch_name, supported in GPU_TO_GFX:
        for model in model_list:
            if model in gpu_lower:
                return gfx, arch_name, supported
    
    return None, None, False

def detect_gpu():
    log("Attempting to detect AMD GPU...")
    
    # Try different detection methods in order of preference
    amd_gpus = []
    
    # Method 1: wmic (fast and works on most systems)
    log("Trying wmic method...")
    amd_gpus = detect_gpu_wmic()
    
    # Method 2: PowerShell (works on all modern Windows)
    if not amd_gpus:
        log("Trying PowerShell method...")
        amd_gpus = detect_gpu_powershell()
    
    if not amd_gpus:
        log("No AMD GPU detected")
        log("If you have an AMD GPU, please ensure your drivers are installed.")
        return None
    
    # Process detected GPUs
    log(f"\nFound {len(amd_gpus)} AMD GPU(s):")
    for gpu in amd_gpus:
        log(f"  - {gpu['name']}  [{gpu.get('pnp_id', 'no PNPDeviceID')}]")
    
    # Try to match to known architectures
    for gpu in amd_gpus:
        gfx, arch_name, supported = match_gpu_to_gfx(gpu)
        
        if gfx and supported:
            log(f"\nMatched GPU: {gpu['name']}")
            log(f"Architecture: {arch_name} ({gfx})")
            log("Status: SUPPORTED")
            return gfx
        elif gfx and not supported:
            log(f"\nMatched GPU: {gpu['name']}")
            log(f"Architecture: {arch_name} ({gfx})")
            log("Status: NOT YET SUPPORTED - Coming in future updates")
            return None
    
    # If we found AMD GPUs but couldn't match them
    log("\nGPU(s) found but architecture could not be identified.")
    log("Only GCN, Vega, RDNA1, RDNA2, RDNA3, and RDNA4 architectures are supported.")
    log("Please check if your GPU is compatible with ROCm.")
    return None

if __name__ == "__main__":
    try:
        gfx = detect_gpu()
        if gfx:
            # ONLY thing allowed on stdout - install.bat's `for /f` captures this
            print(gfx)
            sys.exit(0)
        else:
            sys.exit(1)
    except Exception as e:
        log(f"Fatal error during GPU detection: {e}")
        import traceback
        traceback.print_exc()  # already goes to stderr by default
        sys.exit(1)
