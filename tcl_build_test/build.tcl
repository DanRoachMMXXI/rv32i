read_verilog -sv "test_fpga_module.sv";

read_xdc "build_test.xdc";

set_property generic {N=4} [current_fileset]

synth_design -top "test_fpga_module" -part "xc7a100tcsg324-1";

# place and route
opt_design;
place_design;
route_design;

write_bitstream -force "bitstream.bit"
