# comfyui-rocm

Windows-only version of ComfyUI which uses AMD's official ROCm and PyTorch libraries to get better performance with AMD GPUs.

- [auto-installation and popular performance enhancing packages like triton * sage-attention * flash-attention * bitsandbytes included ]

(Supported GPUs atm : RDNA1, RDNA2 (everything except mobile GPUs and APUs) , RDNA3 and RDNA4)

* on rdna2 these are the supported & unsupported models :

<img width="755" height="207" alt="image" src="https://github.com/user-attachments/assets/8683287c-16d4-4b3b-b238-7aab5f4aa830" />

# NEW #
* Added kijai's hfremotevae nodes , you can now use these for vae decoding (not encoding) for a faster, OOM free decoding for these model types : SD 1.5 , SDXL , Flux , HunyuanVideo and their variants (so for example any model that uses flux vae like the z-image can use this instead)

<img width="1171" height="478" alt="image" src="https://github.com/user-attachments/assets/4d6c19e4-a9c5-4671-8155-92ef08258000" />

<details>
<summary><strong> :: older news :: </strong></summary>
  
* 9000 series (gfx1200) now uses torch 2.12.x by default (2.10 has problems with wan-ltxvideo etc. with these new gpus)
* GPU detection fixed, again.
* Added RDNA1 support.
* Made gpu detection better for windows 11.
* Added full python integration into embedded for better compiling (sage-attention etc needs these files)
* Added advanced settings into `comfyui-rocm.bat` At default they would work without problems, you can modify if you know what you are doing.
* Disabled comfy-aimdo check which keeps giving the same error about being nvidia only, useless for amd at the moment. aimdo is still installed and this was just a warning that shows up each time.
* flash-attention now available for all rdna gpus.
</details>

### Important Note
**DON'T INSTALL** into your user directory or inside Windows or Program Files directories. Don't install to a directory with non-English characters. Best option is to install to the root directory of whichever drive you'd like.

## Installation (Windows-Only)

1) Download and install Git ( available from [https://git-scm.com/download/win](https://git-scm.com/download/win). During installation don't forget to check the box for "Use Git from the Windows Command line and also from 3rd-party software" to add Git to your system's PATH.)
2) Download and install Visual C++ Runtime Library, available from [https://aka.ms/vs/17/release/vc_redist.x64.exe](https://aka.ms/vs/17/release/vc_redist.x64.exe)
3) Download and install Visual Studio Build Tools, available from [https://aka.ms/vs/17/release/vs_BuildTools.exe](https://aka.ms/vs/17/release/vs_BuildTools.exe)
4) Download the latest package from here `https://github.com/patientx-cfz/comfyui-rocm/releases` ; unzip it to a folder of your choice, (preferably root folder of your C or D drive)
5) IF YOU HAVE a cpu with an integrated graphics unit, such as 5600g please disable it from BIOS before attemting to install this fork.
6) Run :

```bash
install.bat
```
* This "hopefully" auto-detects your AMD GPU and installs the correct ROCm & PyTorch packages, I only have an RX6800 and obviously cannot test other AMD GPUs.
* This is partly portable doesn't need Python installed in the system. You can try it separately with `ComfyUI-Zluda`for example, without interfering with it. It also doesn't need HIP installed, those components are now installed into the venv with the ROCm packages. 
* You can use `comfyui-rocm.bat` or put a shortcut of it on your desktop, to run the app later. My recommendation is make a copy of `comfyui-rocm.bat` with another name maybe and modify that copy so when updating you won't get into trouble.
* At the moment, there are some startup options I am using with my RX 6800 in the batch file, you can edit them, I'll try to add more options in there.

## First-Time Launch
* If you have done every previous step correctly, it will install without errors. You can start the app with `comfyui-rocm.bat`. If you already have checkpoints copy them into your `models/checkpoints` folder so you can use them with ComfyUI's default workflows. You can use [ComfyUI's Extra Model Paths YAML file](https://docs.comfy.org/development/core-concepts/models) to specify custom folders.


## Troubleshooting
### Incompatibilities
- DO NOT use non-English characters as folder names to put comfyui-rocm under.
- Make sure you do not have any residual Nvidia graphics drivers installed on your system.

## Credits

- [ComfyUI](https://github.com/comfyanonymous/ComfyUI)
- [AMD TheRock Team](https://github.com/ROCm/TheRock)
- [0xDELUXA](https://github.com/0xDELUXA)
- [kijai](https://github.com/kijai)
