# fpga-video
Simple pixel processing in Verilog

Currently, an NES core ([NES_MiSTer](https://github.com/MiSTer-devel/NES_MiSTer)) is writing to a 256x240 6bpp framebuffer, and it is upscaled 4x and displayed on a 1080p 60Hz display.

Planned features:
- Multi-plane compositing
- EDID parsing
- VSync/triple-buffering
- Reconfigurable timings
