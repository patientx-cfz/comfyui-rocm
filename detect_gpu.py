import subprocess
import sys

# Comprehensive mapping of GPU model numbers to gfx codes
# Format: (model_list, gfx_code, architecture_name, supported)
GPU_TO_GFX = [
    # RDNA4 (gfx12xx)
    (['rx 9060'], 'gfx120X', 'RDNA 4', True),
    (['rx 9070', 'r9070'], 'gfx120X', 'RDNA 4', True),
    
    # RDNA3.5 (gfx115x)
    (['890m'], 'gfx1150', 'Strix Point', True),
    (['8060s', '8050s', '8040s', '880m'], 'gfx1151', 'Strix Halo', True),
    (['860m', '840m', '820m'], 'gfx1152', 'Krackan Point', True),
    (['gfx1153'], 'gfx1153', 'RDNA 3.5', True),
    
    # RDNA3 (gfx110x)
    (['rx 7900', 'w7900', 'w7800'], 'gfx110X', 'RDNA 3', True),
    (['rx 7800', 'rx 7700', 'w7700'], 'gfx110X', 'RDNA 3', True),
    (['rx 7700s', 'rx 7650', 'rx 7600', 'w7600', 'w7500', 'rx 7400', 'w7400'], 'gfx110X', 'RDNA 3', True),
    (['780m', '760m', '740m'], 'gfx110X', 'RDNA 3', True),
    
    # RDNA2 (gfx103x) - ONLY gfx1030 and gfx1032 fully supported
    (['rx 6800m'], 'gfx103X', 'RDNA 2', False),
    (['rx 6800s', 'rx 6700s'], 'gfx103X', 'RDNA 2', True),
    (['rx 6950', 'rx 6900', 'rx 6800', 'w6800'], 'gfx103X', 'RDNA 2', True),
    (['rx 6850', 'rx 6750', 'rx 6700'], 'gfx103X', 'RDNA 2', False),
    (['rx 6650', 'rx 6600', 'w6600'], 'gfx103X', 'RDNA 2', True),
    (['rx 6550', 'rx 6500', 'w6500', 'rx 6450', 'rx 6400', 'w6400', 'rx 6300', 'w6300'], 'gfx103X', 'RDNA 2', False),
    (['680m', '660m'], 'gfx103X', 'RDNA 2', False),
    (['610m'], 'gfx103X', 'RDNA 2', False),

    # RDNA1 (gfx101x)
    (['rx 5700', 'rx 5600'], 'gfx101X', 'RDNA 1', True),
    (['rx 5500', 'radeon pro v520'], 'gfx101X', 'RDNA 1', True),
    
    # Data Center / Enterprise GPUs
    (['radeon pro vii', 'radeon pro vii'], 'gfx90X', 'Radeon Pro VII', True),
    (['mi300a', 'mi300x', 'mi325x'], 'gfx94X', 'MI300/MI325', True),
    (['mi350x', 'mi355x'], 'gfx950', 'MI350/MI355', True),
]

def detect_gpu():
    try:
        # Query AMD GPUs via WMI
        result = subprocess.run(
            ['wmic', 'path', 'win32_videocontroller', 'get', 'name'],
            capture_output=True,
            text=True,
            check=False
        )
        
        gpu_list = result.stdout.strip().split('\n')
        
        for gpu in gpu_list:
            gpu = gpu.strip()
            if not gpu or gpu == "Name":
                continue
            
            if "AMD" in gpu and "Radeon" in gpu:
                gpu_lower = gpu.lower()
                print(f"AMD GPU found: {gpu}")
                
                # Check against supported GPU mapping
                for model_list, gfx, arch_name, supported in GPU_TO_GFX:
                    for model in model_list:
                        if model in gpu_lower:
                            if supported:
                                print(f"Architecture: {arch_name} ({gfx})")
                                return gfx
                            else:
                                print(f"GPU not supported at the moment, will be coming in the future.")
                                return None
                
                # Anything else is unsupported
                print("GPU not supported - Only RDNA2 (gfx103X) and newer are fully supported")
                return None
        
        print("No AMD GPU detected")
        return None
    
    except Exception as e:
        print(f"Error detecting GPU: {e}")
        return None

if __name__ == "__main__":
    gfx = detect_gpu()
    if gfx:
        print(gfx)
        sys.exit(0)
    else:
        sys.exit(1)
