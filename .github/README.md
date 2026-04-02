# comfyui-rocm

Windows-only version of ComfyUI which uses AMD's official ROCM and PyTorch libraries to get better performance with AMD GPUs.

(Supported GPU's atm : RDNA2 (everything except mobile gpu's and apu's) , RDNA3 and RDNA4)

### Important Note
**DON'T INSTALL** into your user directory or inside Windows or Program Files directories. Don't install to a directory with Non-English characters. Best option is to install to the root directory of whichever drive you'd like.
### Important Note

## Installation (Windows-Only)

1) Download and install GIT. ( available from [https://git-scm.com/download/win](https://git-scm.com/download/win). During installation don't forget to check the box for "Use Git from the Windows Command line and also from 3rd-party-software" to add Git to your system's PATH.)
2) Download and install Visual C++ Runtime Library, available from [https://aka.ms/vs/17/release/vc_redist.x64.exe](https://aka.ms/vs/17/release/vc_redist.x64.exe)
3) Download and install Visual Studio Build Tools, available from [https://aka.ms/vs/17/release/vs_BuildTools.exe](https://aka.ms/vs/17/release/vs_BuildTools.exe)
4) Download the latest package from here `https://github.com/patientx-cfz/comfyui-rocm/releases` ; unzip it to a folder of your choice, (preferably root folder of your C or D drive)
5) Run :

```bash
install.bat
```

* This is partly portable doesn't need python installed in the system. You can try it seperately with `Comfyui-Zluda`for example, without interfering with it. It also doesn't need HIP installed , those components are now installed into the venv with the ROCM packages. 
* You can use `comfyui-rocm.bat` or put a shortcut of it on your desktop, to run the app later. My recommendation is make a copy of `comfyui-rocm.bat` with another name maybe and modify that copy so when updating you won't get into trouble.
* At the moment , there are some startup options I am using with my rx 6800 in the batch file, you can edit them , I'll try to add more options in there.

## First-Time Launch
* If you have done every previous step correctly, it will install without errors. You can start the app with `comfyui-rocm.bat`. If you already have checkpoints copy them into your `models/checkpoints` folder so you can use them with ComfyUI's default workflows. You can use [ComfyUI's Extra Model Paths YAML file](https://docs.comfy.org/development/core-concepts/models) to specify custom folders.


## Troubleshooting
### Incompatibilities
- DO NOT use non-english characters as folder names to put comfyui-rocm under.
- Make sure you do not have any residual NVidia graphics drivers instlled on your system.

## Credits

- [ComfyUI](https://github.com/comfyanonymous/ComfyUI)
- [AMD TheRock Team](https://github.com/ROCm/TheRock)
- [0xDELUXA](https://github.com/0xDELUXA)
