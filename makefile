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

sc single_cycle:
	verilator --binary -j 0 test/single_cycle.sv \
		src/common/* \
		src/single_cycle/*

	# maybe useful in the future when I can ditch verilator
	# $(VLOG) test/opcode.sv
	# $(VLOG) $(SRC_INCDIR) src/alu* \
	# 	src/branch_* \
	# 	src/data_memory.sv \
	# 	src/instruction* \
	# 	src/pc_select.sv \
	# 	src/register* \
	# 	src/rf_wb_select.sv \
	# 	src/single_cycle.sv

six_stage_pipeline six ssp:
	verilator --binary -j 0 test/six_stage_pipeline.sv \
		src/common/* \
		src/six_stage_pipeline/*

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

ALU_OPERAND_SELECT_TEST_INCDIR = +incdir+./test/alu_operand_select
alu_op_sel alu_operand_select:
	vlib work

	# uvm package
	$(VLOG) $(UVM_INCDIR) $(UVM_SRC)/uvm_pkg.sv

	# DUT and interface
	$(VLOG) $(UVM_INCDIR) $(ALU_OPERAND_SELECT_TEST_INCDIR) src/alu_operand_select.sv test/alu_operand_select/alu_operand_select_if.sv

	# ALU_OPERAND_SELECT UVM package
	$(VLOG) $(UVM_INCDIR) $(ALU_OPERAND_SELECT_TEST_INCDIR) test/alu_operand_select/alu_operand_select_pkg.sv

	# top level testbench
	$(VLOG) $(UVM_INCDIR) $(ALU_OPERAND_SELECT_TEST_INCDIR) test/alu_operand_select/alu_operand_select_tb_top.sv

	# run simulation
	$(VSIM) $(VSIM_ARGS) alu_operand_select_tb_top

BRANCH_EVALUATOR_TEST_INCDIR = +incdir+./test/branch_evaluator
be branch_evaluator:
	vlib work

	# uvm package
	$(VLOG) $(UVM_INCDIR) $(UVM_SRC)/uvm_pkg.sv

	# DUT and interface
	$(VLOG) $(UVM_INCDIR) $(BRANCH_EVALUATOR_TEST_INCDIR) src/branch_evaluator.sv test/branch_evaluator/branch_evaluator_if.sv

	# BRANCH_EVALUATOR UVM package
	$(VLOG) $(UVM_INCDIR) $(BRANCH_EVALUATOR_TEST_INCDIR) test/branch_evaluator/branch_evaluator_pkg.sv

	# top level testbench
	$(VLOG) $(UVM_INCDIR) $(BRANCH_EVALUATOR_TEST_INCDIR) test/branch_evaluator/branch_evaluator_tb_top.sv

	# run simulation
	$(VSIM) $(VSIM_ARGS) branch_evaluator_tb_top

BRANCH_PREDICTOR_TEST_INCDIR = +incdir+./test/branch_predictor
bp branch_predictor:
	vlib work

	# uvm package
	$(VLOG) $(UVM_INCDIR) $(UVM_SRC)/uvm_pkg.sv

	# DUT and interface
	$(VLOG) $(UVM_INCDIR) $(BRANCH_PREDICTOR_TEST_INCDIR) src/branch_predictor.sv test/branch_predictor/branch_predictor_if.sv

	# BRANCH_PREDICTOR UVM package
	$(VLOG) $(UVM_INCDIR) $(BRANCH_PREDICTOR_TEST_INCDIR) test/branch_predictor/branch_predictor_pkg.sv

	# top level testbench
	$(VLOG) $(UVM_INCDIR) $(BRANCH_PREDICTOR_TEST_INCDIR) test/branch_predictor/branch_predictor_tb_top.sv

	# run simulation
	$(VSIM) $(VSIM_ARGS) branch_predictor_tb_top

INSTRUCTION_DECODE_TEST_INCDIR = +incdir+./test/instruction_decode
instruction_decode id:
	vlib work

	# uvm package
	$(VLOG) $(UVM_INCDIR) $(UVM_SRC)/uvm_pkg.sv

	# opcode constant package
	$(VLOG) test/opcode.sv

	# DUT and interface
	$(VLOG) $(UVM_INCDIR) $(INSTRUCTION_DECODE_TEST_INCDIR) src/instruction_decode.sv test/instruction_decode/instruction_decode_if.sv

	# instruction decode UVM package
	$(VLOG) $(UVM_INCDIR) $(INSTRUCTION_DECODE_TEST_INCDIR) test/instruction_decode/instruction_decode_pkg.sv

	# top level testbench
	$(VLOG) $(UVM_INCDIR) $(INSTRUCTION_DECODE_TEST_INCDIR) test/instruction_decode/instruction_decode_tb_top.sv

	# run simulation
	$(VSIM) $(VSIM_ARGS) instruction_decode_tb_top

PC_SELECT_TEST_INCDIR = +incdir+./test/pc_select
pcsel pc_select:
	vlib work

	# uvm package
	$(VLOG) $(UVM_INCDIR) $(UVM_SRC)/uvm_pkg.sv

	# DUT and interface
	$(VLOG) $(UVM_INCDIR) $(PC_SELECT_TEST_INCDIR) src/pc_select.sv test/pc_select/pc_select_if.sv

	# PC_SELECT UVM package
	$(VLOG) $(UVM_INCDIR) $(PC_SELECT_TEST_INCDIR) test/pc_select/pc_select_pkg.sv

	# top level testbench
	$(VLOG) $(UVM_INCDIR) $(PC_SELECT_TEST_INCDIR) test/pc_select/pc_select_tb_top.sv

	# run simulation
	$(VSIM) $(VSIM_ARGS) pc_select_tb_top

reorder_buffer:
	$(VLOG) src/reorder_buffer.sv

fubuf:
	verilator --binary -j 0 src/out_of_order/functional_unit_output_buffer.sv test/out_of_order/functional_unit_output_buffer.sv

rs:
	verilator --binary -j 0 src/out_of_order/reservation_station.sv test/out_of_order/reservation_station.sv

full_fu:
	verilator --binary -j 0 --top-module test_full_fu src/common/control_signal_bus.sv test/out_of_order/full_fu.sv src/common/alu.sv src/out_of_order/reservation_station.sv src/out_of_order/functional_unit_output_buffer.sv src/out_of_order/alu_functional_unit.sv
	./obj_dir/Vtest_full_fu

cdb_arbiter:
	verilator --binary -j 0 test/out_of_order/cdb_arbiter.sv src/out_of_order/cdb_arbiter.sv
	./obj_dir/Vcdb_arbiter

ldq load_queue:
	verilator --binary -j 0 test/out_of_order/lsu/load_queue.sv src/out_of_order/lsu/load_queue.sv

stq store_queue:
	verilator --binary -j 0 test/out_of_order/lsu/store_queue.sv src/out_of_order/lsu/store_queue.sv

yes youngest_entry_select:
	verilator --binary -j 0 {test,src}/out_of_order/lsu/youngest_entry_select.sv

lsdc load_store_dep_checker:
	verilator --binary -j 0 test/out_of_order/lsu/load_store_dep_checker.sv src/out_of_order/lsu/youngest_entry_select.sv src/out_of_order/lsu/load_store_dep_checker.sv

ofd order_failure_detector:
	verilator --binary -j 0 test/out_of_order/lsu/order_failure_detector.sv src/out_of_order/lsu/age_comparator.sv src/out_of_order/lsu/order_failure_detector.sv

searcher: load_store_dep_checker order_failure_detector

lsu_control:
	verilator --binary -j 0 test/out_of_order/lsu/lsu_control.sv src/out_of_order/lsu/lsu_control.sv src/common/lsb_priority_encoder.sv

lsu load_store_unit:
	verilator --binary -j 0 +define+DEBUG test/out_of_order/lsu/load_store_unit.sv src/out_of_order/lsu/*.sv src/common/lsb_priority_encoder.sv

clean:
	rm -rf work transcript *.log *.wlf
	rm -rf obj_dir
