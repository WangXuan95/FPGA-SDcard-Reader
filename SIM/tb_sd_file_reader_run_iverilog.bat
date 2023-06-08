del sim.out dump.vcd
iverilog  -g2001  -o sim.out  tb_sd_file_reader.v  sd_fake.v  ../RTL/sd_file_reader.v  ../RTL/sd_reader.v  ../RTL/sdcmd_ctrl.v
vvp -n sim.out
del sim.out
pause