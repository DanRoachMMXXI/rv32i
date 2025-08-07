# verilator_cmd = verilator --binary -j 0

# taken from the command line on eda playground and modified to use my path to uvm
# source files come after this

UVM_HOME = ../uvm-1.2
UVM_SRC = $(UVM_HOME)/src

VLOG = vlog
VSIM = vsim

UVM_INCDIR = +incdir+$(UVM_SRC)
 

uvm_component_dir = test/$(1)

uvm_component_incdir = +incdir+$(call uvm_component_dir,$(1))

component_uvm_pkg = $(UVM_INCDIR) $(call uvm_component_incdir,alu) $(call uvm_component_dir,alu)/$(1)_pkg.sv
component_uvm_tb = $(UVM_INCDIR) $(call uvm_component_incdir,alu) test/$(1)/$(1)_tb_top.sv
run_uvm_sim = -sv_lib $(UVM_HOME)/lib/uvm_dpi64 -c -do "run -all; quit" $(1)_tb_top

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

alu:
	# uvm package
	$(VLOG) $(UVM_INCDIR) $(UVM_SRC)/uvm_pkg.sv

	# DUT and interface
	$(VLOG) $(UVM_INCDIR) +incdir+./test/alu src/alu.sv test/alu/alu_if.sv

	# package
	$(VLOG) $(UVM_INCDIR) +incdir+./test/alu test/alu/alu_pkg.sv

	# components
	$(VLOG) $(UVM_INCDIR) +incdir+./test/alu test/alu/alu_driver.sv test/alu/alu_monitor.sv test/alu/alu_agent.sv test/alu/alu_env.sv test/alu/alu_scoreboard.sv test/alu/alu_test.sv

	# top level testbench
	$(VLOG) $(UVM_INCDIR) +incdir+./test/alu test/alu/alu_tb_top.sv

	# old code
	# $(compile_uvm_pkg)
	# $(VLOG) src/alu.sv test/alu/alu_if.sv
	# $(VLOG) $(call component_uvm_pkg,alu)
	# $(VLOG) $(call component_uvm_tb,alu)

	# run simulation
	# $(VSIM) $(call run_uvm_sim,alu)

register_file:
	$(VLOG) src/register_file.sv test/register_file_tb.sv

instruction_decode:
	$(VLOG) src/instruction_decode.sv test/instruction_decode_tb.sv

memory:
	$(VLOG) src/memory.sv

branch:
	$(VLOG) src/branch_*.sv test/branch_tb.sv

reorder_buffer:
	$(VLOG) src/reorder_buffer.sv

clean:
	rm -rf work transcript *.log *.wlf
