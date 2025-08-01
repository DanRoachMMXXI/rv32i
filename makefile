# verilator_cmd = verilator --binary -j 0

# taken from the command line on eda playground and modified to use my path to uvm
# source files come after this

UVM_HOME = ../uvm-1.2/src
VLOG = vlog
VSIM = vsim

UVM_INCDIR = +incdir+$(UVM_HOME)
 

uvm_component_dir = test/$(1)

uvm_component_incdir = +incdir+$(call uvm_component_dir,$(1))

component_uvm_pkg = $(UVM_INCDIR) $(call uvm_component_incdir,alu) $(call uvm_component_dir,alu)/$(1)_pkg.sv
component_uvm_tb = $(UVM_INCDIR) $(call uvm_component_incdir,alu) test/$(1)/$(1)_tb_top.sv
run_uvm_sim = -c -do "run -all; quit" $(1)_tb_top

uvm:
	$(VLOG) $(UVM_INCDIR) $(UVM_HOME)/uvm_pkg.sv

single_cycle:
	$(VLOG) src/*.sv --top-module single_cycle

alu:
	# uvm package
	$(VLOG) $(UVM_INCDIR) $(UVM_HOME)/uvm_pkg.sv

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
	$(VSIM) $(call run_uvm_sim,alu)

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
