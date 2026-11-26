# Source-controlled SoC build

The checked-in Tcl first builds `riscv_mc_helloworld` with the Propel SDK Makefile, then recreates the Propel design with that firmware loaded into `system0`, and finally runs Radiant through bitstream generation. Keep `.gitignore`, `.socproject`, this document, `build_all.tcl`, both tool scripts, `my_soc.rdf`, `my_soc1.sty`, `my_soc/my_soc_Top.v`, the sources and constraints referenced under `source/`, the custom IP package under `propel_ip_local/`, and the SDK project metadata and source under `riscv_mc_helloworld/`. Do not check in `.sbx` files, the SDK `Debug/` or `build/` output, or generated Radiant `impl_1/` and Propel `my_soc/lib/` outputs.

The script uses the Lattice IP catalog versions named in `propel_rebuild.tcl`; make sure those IPs are available in the installed Propel Builder. The project's custom APB-register package is included under `propel_ip_local/`.

## Run the build

From PowerShell, run `build_all.tcl` with the Tcl interpreter shipped with Propel. With the default install locations:

```powershell
& 'C:\lscc\propel\2025.1\builder\rtf\tcltk\windows\bin\tclsh.exe' 'C:\path\to\my_soc\build_all.tcl'
```

If Propel or Radiant is installed elsewhere, set `PROPEL_HOME` and/or `RADIANT_HOME` before running the command. The Tcl script finds the project root from its own location, so use the absolute path to `build_all.tcl`.

The runner builds the SDK firmware ELF, binary, and 32-bit-word memory image in `riscv_mc_helloworld\build`, then Propel recreates the Builder project under `build\propel\my_soc` with that memory image configured for `system0`. The root `.socproject` can be opened in Propel Builder after the build. Radiant generates `impl_1\my_soc_impl_1.bit`.

The firmware project uses the RISC-V compiler, Make, and `srec_cat` bundled with the selected Propel installation. You can also build the firmware alone with `C:\lscc\propel\2025.1\sdk\build_tools\bin\make.exe -C C:\path\to\my_soc\riscv_mc_helloworld`; set `PROPEL_HOME` first if Propel is installed elsewhere.

On later runs, the Propel script replaces only its marked generated project directory under `build\propel`; close that generated project in Propel Builder before rebuilding. Do not put user-authored files in that generated directory.

The tools may report existing APB address-width mismatch warnings between the APB interconnect and GPIO/UART. The design generation succeeds, but these warnings are not corrected by the source-control scripts.

Radiant's latest run generated the bitstream with no bitstream DRC errors or warnings, but timing closure was not met: the timing report showed worst slack of -3.908 ns, and Radiant reported missing source-clock and `set_clock_uncertainty` constraints on the PLL outputs. Review the clock constraints before treating the bitstream as timing signoff.
