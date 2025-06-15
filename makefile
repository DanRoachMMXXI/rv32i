alu:
	verilator --binary -j 0 src/alu.sv test/alu_tb.sv

register_file:
	verilator --binary -j 0 src/register_file.sv test/register_file_tb.sv

clean:
	rm -r obj_dir
