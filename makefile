# verilator_cmd = verilator --binary -j 0

# taken from the command line on eda playground and modified to use my path to uvm
# source files come after this

UVM_HOME = ../uvm-1.2
UVM_SRC = $(UVM_HOME)/src

VLOG = vlog
VSIM = vsim
VSIM_ARGS = -sv_lib $(UVM_HOME)/lib/uvm_dpi64 -c -do "run -all; quit"

SRC_INCDIR = +incdir+./src
UVM_INCDIR = +incdir+$(UVM_SRC)
BASE_TEST_INCDIR = +incdir+./test

GCC = riscv32-unknown-elf-gcc -nostdlib -T test/programs/linker.ld test/programs/init.s
OBJCOPY = riscv32-unknown-elf-objcopy -O verilog
OBJDUMP = riscv32-unknown-elf-objdump -d

uvm:
	$(VLOG) $(UVM_INCDIR) $(UVM_SRC)/uvm_pkg.sv

single_cycle:
	verilator --binary -j 0 test/single_cycle.sv \
		src/opcode.sv \
		src/alu* \
		src/branch_* \
		src/data_memory.sv \
		src/instruction* \
		src/pc_select.sv \
		src/register* \
		src/rf_wb_select.sv \
		src/single_cycle.sv

	# maybe useful in the future when I can ditch verilator
	# $(VLOG) src/opcode.sv
	# $(VLOG) $(SRC_INCDIR) src/alu* \
	# 	src/branch_* \
	# 	src/data_memory.sv \
	# 	src/instruction* \
	# 	src/pc_select.sv \
	# 	src/register* \
	# 	src/rf_wb_select.sv \
	# 	src/single_cycle.sv

simple-sum:
	$(GCC) test/programs/simple-sum/simple-sum.c -o test/programs/simple-sum/simple-sum.elf
	$(OBJCOPY) test/programs/simple-sum/simple-sum.elf test/programs/simple-sum/simple-sum.vh
	$(OBJDUMP) test/programs/simple-sum/simple-sum.elf

simple-loop:
	$(GCC) test/programs/simple-loop/simple-loop.c -o test/programs/simple-loop/simple-loop.elf
	$(OBJCOPY) test/programs/simple-loop/simple-loop.elf test/programs/simple-loop/simple-loop.vh
	$(OBJDUMP) test/programs/simple-loop/simple-loop.elf

matrix four-by-four-matrix:
	$(GCC) test/programs/four-by-four-matrix/four-by-four-matrix.c -o test/programs/four-by-four-matrix/four-by-four-matrix.elf
	$(OBJCOPY) test/programs/four-by-four-matrix/four-by-four-matrix.elf test/programs/four-by-four-matrix/four-by-four-matrix.vh
	$(OBJDUMP) test/programs/four-by-four-matrix/four-by-four-matrix.elf

ALU_TEST_INCDIR = +incdir+./test/alu
alu:
	vlib work

	# uvm package
	$(VLOG) $(UVM_INCDIR) $(UVM_SRC)/uvm_pkg.sv

	# DUT and interface
	$(VLOG) $(UVM_INCDIR) $(ALU_TEST_INCDIR) src/alu.sv test/alu/alu_if.sv

	# ALU UVM package
	$(VLOG) $(UVM_INCDIR) $(ALU_TEST_INCDIR) test/alu/alu_pkg.sv

	# top level testbench
	$(VLOG) $(UVM_INCDIR) $(ALU_TEST_INCDIR) test/alu/alu_tb_top.sv

	# run simulation
	$(VSIM) $(VSIM_ARGS) alu_tb_top

INSTRUCTION_DECODE_TEST_INCDIR = +incdir+./test/instruction_decode
instruction_decode:
	vlib work

	# uvm package
	$(VLOG) $(UVM_INCDIR) $(UVM_SRC)/uvm_pkg.sv

	# opcode constant package
	$(VLOG) src/opcode.sv

	# DUT and interface
	$(VLOG) $(UVM_INCDIR) $(INSTRUCTION_DECODE_TEST_INCDIR) src/instruction_decode.sv test/instruction_decode/instruction_decode_if.sv

	# instruction decode UVM package
	$(VLOG) $(UVM_INCDIR) $(INSTRUCTION_DECODE_TEST_INCDIR) test/instruction_decode/instruction_decode_pkg.sv

	# top level testbench
	$(VLOG) $(UVM_INCDIR) $(INSTRUCTION_DECODE_TEST_INCDIR) test/instruction_decode/instruction_decode_tb_top.sv

	# run simulation
	$(VSIM) $(VSIM_ARGS) instruction_decode_tb_top

reorder_buffer:
	$(VLOG) src/reorder_buffer.sv

clean:
	rm -rf work transcript *.log *.wlf
