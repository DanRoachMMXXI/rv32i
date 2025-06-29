verilator_cmd = verilator --binary -j 0

all:
	$(verilator_cmd) src/*.sv

alu:
	$(verilator_cmd) src/alu.sv test/alu_tb.sv

register_file:
	$(verilator_cmd) src/register_file.sv test/register_file_tb.sv

instruction_decode:
	$(verilator_cmd) src/instruction_decode.sv test/instruction_decode_tb.sv

memory:
	$(verilator_cmd) src/memory.sv

branch_module:
	$(verilator_cmd) src/branch_module.sv

clean:
	rm -r obj_dir
