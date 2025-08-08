# verilator_cmd = verilator --binary -j 0

# taken from the command line on eda playground and modified to use my path to uvm
# source files come after this

UVM_HOME = ../uvm-1.2
UVM_SRC = $(UVM_HOME)/src

VLOG = vlog
VSIM = vsim
VSIM_ARGS = -sv_lib $(UVM_HOME)/lib/uvm_dpi64 -c -do "run -all; quit"

UVM_INCDIR = +incdir+$(UVM_SRC)
BASE_TEST_INCDIR = +incdir+./test

GCC = riscv32-unknown-elf-gcc -nostdlib -T test/programs/linker.ld test/programs/init.s
OBJCOPY = riscv32-unknown-elf-objcopy -O verilog
OBJDUMP = riscv32-unknown-elf-objdump -d

uvm:
	$(VLOG) $(UVM_INCDIR) $(UVM_SRC)/uvm_pkg.sv

single_cycle:
	verilator --binary -j 0 test/single_cycle.sv \
		src/alu* \
		src/branch_* \
		src/data_memory.sv \
		src/instruction* \
		src/pc_select.sv \
		src/register* \
		src/rf_wb_select.sv \
		src/single_cycle.sv

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
	# uvm package
	$(VLOG) $(UVM_INCDIR) $(UVM_SRC)/uvm_pkg.sv

	# DUT and interface
	$(VLOG) $(UVM_INCDIR) $(ALU_TEST_INCDIR) src/alu.sv test/alu/alu_if.sv

	# base uvm components - alu uvm components will derive from these
	$(VLOG) $(UVM_INCDIR) $(BASE_TEST_INCDIR) test/base_combinational_agent.sv

	# package
	$(VLOG) $(UVM_INCDIR) $(ALU_TEST_INCDIR) test/alu/alu_pkg.sv

	# components
	$(VLOG) $(UVM_INCDIR) $(ALU_TEST_INCDIR) test/alu/alu_driver.sv test/alu/alu_monitor.sv test/alu/alu_agent.sv test/alu/alu_env.sv test/alu/alu_scoreboard.sv test/alu/alu_test.sv

	# top level testbench
	$(VLOG) $(UVM_INCDIR) $(ALU_TEST_INCDIR) test/alu/alu_tb_top.sv

	# run simulation
	$(VSIM) $(VSIM_ARGS) alu_tb_top

register_file:
	$(VLOG) src/register_file.sv test/register_file_tb.sv

instruction_decode:
	$(VLOG) src/instruction_decode.sv test/instruction_decode_tb.sv

memory:
	$(VLOG) src/memory.sv

branch:
	$(VLOG) src/branch_*.sv

reorder_buffer:
	$(VLOG) src/reorder_buffer.sv

clean:
	rm -rf work transcript *.log *.wlf
