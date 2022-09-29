del sim.out dump.vcd
iverilog  -g2005-sv  -o sim.out  tb_sd_file_reader.sv  sd_fake.sv  ../RTL/sd_file_reader.sv  ../RTL/sd_reader.sv  ../RTL/sdcmd_ctrl.sv
vvp -n sim.out
del sim.out
pause