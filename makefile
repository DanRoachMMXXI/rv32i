# taken from the command line on eda playground and modified to use my path to uvm
# source files come after this

UVM_HOME = ../uvm-1.2
UVM_SRC = $(UVM_HOME)/src

VLOG = vlog
VSIM = vsim
VSIM_ARGS = -sv_lib $(UVM_HOME)/lib/uvm_dpi64 -c -do "run -all; quit"

VERILATOR = verilator --binary -j 0

SRC_INCDIR = +incdir+./src
UVM_INCDIR = +incdir+$(UVM_SRC)
BASE_TEST_INCDIR = +incdir+./test

GCC = riscv32-unknown-elf-gcc -nostdlib -T test/programs/linker.ld test/programs/init.s
OBJCOPY = riscv32-unknown-elf-objcopy -O verilog
OBJDUMP = riscv32-unknown-elf-objdump -d

uvm:
	$(VLOG) $(UVM_INCDIR) $(UVM_SRC)/uvm_pkg.sv

sc single_cycle:
	$(VERILATOR) test/single_cycle.sv \
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
	$(VERILATOR) test/six_stage_pipeline.sv \
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

qs qsort quicksort:
	$(GCC) test/programs/quicksort/quicksort.c -o test/programs/quicksort/quicksort.elf
	$(OBJCOPY) test/programs/quicksort/quicksort.elf test/programs/quicksort/quicksort.vh
	$(OBJDUMP) test/programs/quicksort/quicksort.elf

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

	$(VLOG) src/common/control_signal_bus.sv 

	# DUT and interface
	$(VLOG) $(UVM_INCDIR) $(INSTRUCTION_DECODE_TEST_INCDIR) src/common/instruction_decode.sv test/instruction_decode/instruction_decode_if.sv

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

reorder_buffer rob:
	# $(VLOG) src/reorder_buffer.sv
	$(VERILATOR) --top-module test_reorder_buffer test/backend/reorder_buffer.sv test/backend/instruction_type.sv src/backend/reorder_buffer.sv src/common/lsb_priority_encoder.sv

fubuf:
	$(VERILATOR) --top-module test_functional_unit_output_buffer src/backend/functional_unit_output_buffer.sv test/backend/functional_unit_output_buffer.sv src/common/fixed_priority_arbiter.sv src/common/lsb_priority_encoder.sv

rs:
	$(VERILATOR) --top-module test_reservation_station src/common/control_signal_bus.sv test/backend/reservation_station.sv src/backend/reservation_station.sv

full_fu:
	$(VERILATOR) --top-module test_full_fu src/frontend/control_signal_bus.sv test/out_of_order/full_fu.sv src/backend/alu/*.sv src/backend/reservation_station.sv src/backend/functional_unit_output_buffer.sv
	./obj_dir/Vtest_full_fu

cdb_arbiter:
	$(VERILATOR) test/backend/cdb_arbiter.sv src/backend/cdb_arbiter.sv
	./obj_dir/Vcdb_arbiter

ldq load_queue:
	$(VERILATOR) test/backend/lsu/load_queue.sv src/backend/lsu/load_queue.sv

stq store_queue:
	$(VERILATOR) test/backend/lsu/store_queue.sv src/backend/lsu/store_queue.sv

yes youngest_entry_select:
	$(VERILATOR) {test,src}/backend/lsu/youngest_entry_select.sv

lsdc load_store_dep_checker:
	$(VERILATOR) test/backend/lsu/load_store_dep_checker.sv src/backend/lsu/youngest_entry_select.sv src/backend/lsu/load_store_dep_checker.sv

ofd order_failure_detector:
	$(VERILATOR) test/backend/lsu/order_failure_detector.sv src/backend/lsu/order_failure_detector.sv

searcher: load_store_dep_checker order_failure_detector

lsu_control:
	$(VERILATOR) test/backend/lsu/lsu_control.sv src/backend/lsu/lsu_control.sv src/common/lsb_priority_encoder.sv

lsu load_store_unit:
	$(VERILATOR) +define+DEBUG test/backend/lsu/load_store_unit.sv src/backend/lsu/*.sv src/common/lsb_priority_encoder.sv

instruction_route ir:
	$(VERILATOR) --top-module test_instruction_route test/frontend/instruction_route.sv src/frontend/instruction_route.sv src/common/fixed_priority_arbiter.sv

full_branch_fu bfu:
	$(VERILATOR) --top-module test_full_branch_fu src/common/*.sv test/out_of_order/branch/full_branch_fu.sv src/out_of_order/branch/*.sv src/out_of_order/instruction_route.sv src/out_of_order/cdb_arbiter.sv src/out_of_order/functional_unit_output_buffer.sv src/out_of_order/reorder_buffer.sv src/out_of_order/reservation_station.sv src/out_of_order/rf_writeback.sv src/out_of_order/pc_mux.sv

return_address_stack ras:
	$(VERILATOR) test/backend/branch/return_address_stack.sv src/out_of_order/branch/return_address_stack.sv

test_ooo_rf:
	$(VERILATOR) test/out_of_order/register_file_modifications.sv src/common/register_file.sv

ooo_cpu ooocpu:
	$(VERILATOR) --top-module cpu src/frontend/*.sv src/backend/*.sv src/backend/*/*.sv src/out_of_order_cpu.sv src/common/*.sv

testooo:
	$(VERILATOR) --top-module test_ooo_cpu src/frontend/*.sv test/out_of_order/cpu.sv src/backend/*.sv src/backend/*/*.sv src/out_of_order_cpu.sv src/common/*.sv

clean:
	rm -rf work transcript *.log *.wlf
	rm -rf obj_dir
