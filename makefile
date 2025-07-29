# verilator_cmd = verilator --binary -j 0

# taken from the command line on eda playground and modified to use my path to uvm
# source files come after this

UVM_HOME = ../uvm-1.2/src
VLOG = vlog

UVM_INCDIR = +incdir+$(UVM_HOME)

component_uvm_pkg = $(UVM_INCDIR) +incidr+test/$(1) test/$(1)/$(1)_pkg.sv

uvm:
	$(VLOG) $(UVM_INCDIR) $(UVM_HOME)/uvm_pkg.sv

single_cycle:
	$(VLOG) src/*.sv --top-module single_cycle

alu:
	$(compile_uvm_pkg)
	$(VLOG) src/alu.sv test/alu/alu_if.sv
	$(VLOG) $(call component_uvm_pkg,alu)

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
