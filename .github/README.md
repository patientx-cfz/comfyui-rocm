# comfyui-rocm

Windows-only version of ComfyUI that uses AMD's official ROCm and PyTorch libraries to achieve better performance on AMD GPUs.

[includes auto-installation and popular performance-enhancing packages such as Triton, Sage Attention, Flash Attention, and bitsandbytes]

- Currently supported GPUs: RDNA1, RDNA2 (everything except mobile GPUs and APUs), RDNA3 and RDNA4.

On RDNA2 these are the supported & unsupported models:

<img width="755" height="207" alt="image" src="https://github.com/user-attachments/assets/8683287c-16d4-4b3b-b238-7aab5f4aa830" />

# NEW #
* Added some tested workflows inside "sample-workflows" folder. Wan 2.2 i2v & ltxv2.3 distill model only and 2-stage dev model using distill lora workflows are added at the moment.
* Added kijai's hfremotevae nodes. You can now use these for VAE decoding (not encoding) for faster, OOM-free decoding for these model types: SD 1.5, SDXL, Flux, HunyuanVideo and their variants (for example, any model that uses the Flux VAE like the z-image model can use this instead).

<img width="1171" height="478" alt="image" src="https://github.com/user-attachments/assets/4d6c19e4-a9c5-4671-8155-92ef08258000" />

<details>
<summary><strong> :: Older news :: </strong></summary>

* 9000 series (gfx120X) now uses torch 2.12 by default (2.10 has issues with Wan/LTXVideo etc. + FP8 on these new GPUs).
* GPU detection fixed, again.
* Added RDNA1 support.
* Made GPU detection better for Windows 11.
* Added full Python integration into embedded for better compiling (Sage Attention etc. needs these files).
* Added advanced settings into `comfyui-rocm.bat`. At default they will work without problems; you can modify them if you know what you are doing.
* Disabled comfy-aimdo check which kept giving the same error about being NVIDIA-only - useless for AMD at the moment. aimdo is still installed and this was just a warning that showed up each time.
* Flash Attention is now available for all RDNA GPUs.
</details>

### Important Note
**DON'T INSTALL** into your user directory or inside Windows or Program Files directories. Don't install to a directory with non-English characters. The best option is to install to the root directory of whichever drive you'd like.

## Installation (Windows-Only)

1) Download and install Git (available from [https://git-scm.com/download/win](https://git-scm.com/download/win)). During installation, don't forget to check the box for "Use Git from the Windows Command Line and also from 3rd-party software" to add Git to your system's PATH.
2) Download and install the Visual C++ Runtime Library, available from [https://aka.ms/vs/17/release/vc_redist.x64.exe](https://aka.ms/vs/17/release/vc_redist.x64.exe).
3) Download and install Visual Studio Build Tools, available from [https://aka.ms/vs/17/release/vs_BuildTools.exe](https://aka.ms/vs/17/release/vs_BuildTools.exe).
4) Download the latest package from `https://github.com/patientx-cfz/comfyui-rocm/releases`, unzip it to a folder of your choice (preferably the root folder of your C or D drive).
5) IF YOU HAVE a CPU with an integrated graphics unit, such as a 5600G, please disable it from BIOS before attempting to install this fork.
6) Run:

```bash
install.bat
```
* This "hopefully" auto-detects your AMD GPU and installs the correct ROCm & PyTorch packages. I only have an RX 6800 and obviously cannot test other AMD GPUs.
* This is partly portable and doesn't need Python installed on the system. You can try it separately with `ComfyUI-Zluda` for example, without interfering with your existing setup. It also doesn't need HIP installed, as those components are now installed into the venv with the ROCm packages.
* You can use `comfyui-rocm.bat`, or put a shortcut to it on your desktop, to run the app later. My recommendation is to make a copy of `comfyui-rocm.bat` with another name and modify that copy, so that when updating you won't run into trouble.
* At the moment, there are some startup options I am using with my RX 6800 in the batch file. You can edit them; I'll try to add more options in there.

## First-Time Launch
* If you have completed every previous step correctly, it will install without errors. You can start the app with `comfyui-rocm.bat`. If you already have checkpoints, copy them into your `models/checkpoints` folder so you can use them with ComfyUI's default workflows. You can use [ComfyUI's Extra Model Paths YAML file](https://docs.comfy.org/development/core-concepts/models) to specify custom folders.

## Troubleshooting
### Incompatibilities
- DO NOT use non-English characters as folder names anywhere in the comfyui-rocm path.
- Make sure you do not have any residual NVIDIA graphics drivers installed on your system.

## Credits

- [ComfyUI](https://github.com/comfyanonymous/ComfyUI)
- [AMD TheRock Team](https://github.com/ROCm/TheRock)
- [0xDELUXA](https://github.com/0xDELUXA)
- [kijai](https://github.com/kijai)
