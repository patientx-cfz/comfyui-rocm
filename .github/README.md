# comfyui-rocm

Windows-only version of ComfyUI that uses AMD's official ROCm and PyTorch libraries to achieve better performance on AMD GPUs.

[includes auto-installation and popular performance-enhancing packages such as Triton, Sage Attention, Flash Attention, and bitsandbytes]

- Currently supported GPUs: GCN5 /Vega, RDNA1, RDNA2 , RDNA3 and RDNA4.

# NEWS #

* The included [ComfyUI-INT8-Fast-ROCM](https://github.com/patientx/ComfyUI-INT8-Fast-ROCM) got an important update. It now has a global "hijacker" that reroutes all int8 operations to the node's int8 kernel, so we can load int8 models and vae's through native comfyui loaders. (the custom node's loaders are still usable) It is only activated automatically below rdna3 so newer gpu's won't be forced to use it unless they use the custom laoders.
* `rocm-pytorch-package-updater.bat` added. Easily update the rocm and pytorch packages to the latest ones available. Useful when a newer rocm-pytorch might be the solution or have some enhancements - speedups over what was installed during the first time. (Not app itself, that is still updated via `comfyui-rocm-updater.bat`) 
* You can use int4 models & int8 clips models with the [ComfyUI-INT8-Fast-ROCM](https://github.com/patientx/ComfyUI-INT8-Fast-ROCM) (have to update it to the latest version) Details in its readme.
* The included [ComfyUI-INT8-Fast-ROCM](https://github.com/patientx/ComfyUI-INT8-Fast-ROCM) now converts directly to a comfyui native loader compatible int8-convrot format. At the moment the native loader is either slow or have problems with AMD GPUs. So for better speed and compability with AMD just use this nodes loader. The only odd model out of all I tested was qwen-image-edit and to make it work I had to choose dtype as float32 manually. Every model I tested is faster than native loader (if one can make native loader work with patches etc). So please try the custom loader.
  <img width="446" height="306" alt="image" src="https://github.com/user-attachments/assets/cf103398-404c-4ff7-8f92-96704e8f427d" />


* Updated the rocm & pytorch builds to the multi-arch builds, this shouldn't cause many problems, so far only gfx942 and gfx950 doesn't seem to have windows builds yet, they are set to use the old urls for the time being.Obviously I can't test for every gpu out there so please open an issue if your gpu isn't getting recognized by this new system.
  
* Added my fork of the [ComfyUI-INT8-Fast](https://github.com/BobJohnson24/ComfyUI-INT8-Fast) , [ComfyUI-INT8-Fast-ROCM](https://github.com/patientx/ComfyUI-INT8-Fast-ROCM) ; which essentially lets us use int8 quantized models with triton ; one needs bf16 version of the model they need to quantize or can download various prequantized models on huggingface or civitai. With every model I've tested everyone one of them was faster -at least 25 to 40 percent- and better or identical quality then fp8 quantizations. Sage-attention can be added with models that support it by starting comfyui with --use-sage-attention or using the "patch sage attention" node from kjnodes. This really helps with the gen times.
  
* Added color-coding to both installer and starter bat file.
  
* Added logging and `--debug` option for `install.bat` 

<details>
<summary><strong> :: Older news :: </strong></summary>

* Thanks to the latest updates on [TheRock](https://github.com/ROCm/TheRock) , we now have full gpu support from gcn5/vega to the latest RDNA4 gpu's.
* Added a simple updater, run it to keep your install of comfyui-rocm updated.
* Added some tested workflows inside "sample-workflows" folder. Wan 2.2 i2v & ltxv2.3 distill model only and 2-stage dev model using distill lora workflows are added at the moment.
* Added kijai's hfremotevae nodes. You can now use these for VAE decoding (not encoding) for faster, OOM-free decoding for these model types: SD 1.5, SDXL, Flux, HunyuanVideo and their variants (for example, any model that uses the Flux VAE like the z-image model can use this instead).

<img width="1171" height="478" alt="image" src="https://github.com/user-attachments/assets/4d6c19e4-a9c5-4671-8155-92ef08258000" />
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
* If you want detailed output to see what is installed / downloaded during installation process , use `install.bat --debug` instead.
* This "hopefully" auto-detects your AMD GPU and installs the correct ROCm & PyTorch packages. I only have an RX 6800 and obviously cannot test other AMD GPUs.
* This is partly portable and doesn't need Python installed on the system. You can try it separately with `ComfyUI-Zluda` for example, without interfering with your existing setup. It also doesn't need HIP installed, as those components are now installed into the venv with the ROCm packages.
* Running `comfyui-rocm-updater.bat` at least once before running comfyui-rocm for the first time is recommended, this would make sure you are using latest version as of the time you are installing it. And make sure to run `comfyui-rocm-updater.bat` regularly to keep the app up-to-date.
* You can use `comfyui-user.bat`, or put a shortcut to it on your desktop, to run the app later. My recommendation is to make a copy of `comfyui-user.bat` with another name and modify that copy, so that when updating you won't run into trouble. (don't make changes in the `comfyui-rocm.bat` ; instead use and edit `comfyui-user.bat`)
* At the moment, there are some startup options I am using with my RX 6800 in the batch file. You can edit them; I'll try to add more options in there.

## First-Time Launch
* If you have completed every previous step correctly, it will install without errors. You can start the app with `comfyui-user.bat`. If you already have checkpoints, copy them into your `models/checkpoints` folder so you can use them with ComfyUI's default workflows. You can use [ComfyUI's Extra Model Paths YAML file](https://docs.comfy.org/development/core-concepts/models) to specify custom folders.

## Troubleshooting
### Incompatibilities
- DO NOT use non-English characters as folder names anywhere in the comfyui-rocm path.
- Make sure you do not have any residual NVIDIA graphics drivers installed on your system.

## Credits

- [ComfyUI](https://github.com/comfyanonymous/ComfyUI)
- [AMD TheRock Team](https://github.com/ROCm/TheRock)
- [0xDELUXA](https://github.com/0xDELUXA)
- [kijai](https://github.com/kijai)
