`include "uvm_macros.svh"
import uvm_pkg::*;

import branch_evaluator_pkg::*;

import opcode::*;

class branch_evaluator_scoreboard #(parameter XLEN=32) extends uvm_component;
	`uvm_component_utils(branch_evaluator_scoreboard)

	uvm_analysis_imp #(branch_evaluator_transaction, branch_evaluator_scoreboard) analysis_export;
	// no need for the expected state here, it's a combinational component
	
	function new(string name, uvm_component parent);
		super.new(name, parent);
		analysis_export = new("analysis_export", this);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
	endfunction

	function void write(branch_evaluator_transaction tx);
		if (!validate_immediate(tx.instruction, tx.immediate))
			`uvm_error("SCOREBOARD", $sformatf("Immediate value 0x%0h mismatched expected output 0x%0h for instruction 0x%0h", tx.immediate, expected_immediate(tx.instruction), tx.instruction))
		else
			`uvm_info("SCOREBOARD", $sformatf("Immediate value 0x%0h matched expected output for instruction 0x%0h", tx.immediate, tx.instruction), UVM_NONE)

		validate_branch_signals(tx);	// no need to return anything - validation done inside the function
		validate_alu_signals(tx);
		validate_misc_signals(tx);
	endfunction

	function logic validate_immediate(logic[31:0] instruction, logic[XLEN-1:0] immediate);
		if (instruction[6:0] == R_TYPE)
			// nothing to validate, any immediate is acceptable
			// because no control signals will route it to
			// anything that changes the state of the cpu
			return 1;
		else if (instruction[6:0] inside { opcodes })	// all other valid opcodes
			return immediate == expected_immediate(instruction);
		else
			return 0;	// unsupported opcode
	endfunction

	function logic[XLEN-1:0] expected_immediate(logic[31:0] instruction);
		if (instruction[6:0] inside { I_TYPE_ALU, I_TYPE_LOAD, I_TYPE_JALR })
			return {
				{XLEN{instruction[31]}},
				instruction[31:20]
			};
		else if (instruction[6:0] == B_TYPE)
			return {
				{XLEN{instruction[31]}},
				instruction[31],
				instruction[7],
				instruction[30:25],
				instruction[11:8],
				1'b0
			};
		else if (instruction[6:0] == S_TYPE)
			return {
				{XLEN{instruction[31]}},
				instruction[31:25],
				instruction[11:7]
			};
		else if (instruction[6:0] == JAL)
			return {
				{XLEN{instruction[31]}},
				instruction[20],
				instruction[10:1],
				instruction[11],
				instruction[19:12],
				1'b0
			};
		else if (instruction[6:0] inside { LUI, AUIPC })
			return {
				instruction[31:12],
				{12{1'b0}}
			};
		else
			return 0;	// unsupported opcode
	endfunction

	/*
	* Validating all the instruction decode signals might be a complete
	* organizational nightmare due to how many fucking signals there are
	* coming out of this one component.  This could be indicative of
	* a need to restructure my decoding logic into smaller more
	* comprehensible components.  I've already got most of those signals
	* modularized anyways.
	*
	* Anyways for now, I'm going to structure this test in the following
	* ways
	* validate_<component>_signals
	* + validate_<signal1>
	* | + <signal1> == expected_<signal1>
	* + validate_<signal2>
	* | + <signal2> == expected_<signal2>
	* + ...
	*/
	function void validate_branch_signals(branch_evaluator_transaction tx);
		// expected signals
		logic expected_jump = expected_jump_f(tx.instruction);
		logic expected_branch = expected_branch_f(tx.instruction);
		logic expected_branch_if_zero = expected_branch_if_zero_f(tx.instruction);
		logic expected_branch_base = expected_branch_base_f(tx.instruction);

		// validate tx.jump
		if (tx.jump != expected_jump) begin
			`uvm_error("SCOREBOARD", $sformatf("jump signal %d did not match the expected value %d for instruction 0x%0h", tx.jump, expected_jump, tx.instruction))
		end

		// validate tx.branch
		if (tx.branch != expected_branch) begin
			`uvm_error("SCOREBOARD", $sformatf("branch signal %d did not match the expected value %d for instruction 0x%0h", tx.branch, expected_branch, tx.instruction))
		end

		// validate tx.branch_if_zero
		if (tx.branch_if_zero != expected_branch_if_zero) begin
			`uvm_error("SCOREBOARD", $sformatf("branch_if_zero signal %d did not match the expected value %d for instruction 0x%0h", tx.branch_if_zero, expected_branch_if_zero, tx.instruction))
		end

		// validate tx.branch_base
		if (tx.branch_base != expected_branch_base) begin
			`uvm_error("SCOREBOARD", $sformatf("branch_base signal %d did not match the expected value %d for instruction 0x%0h", tx.branch_base, expected_branch_base, tx.instruction))
		end
	endfunction

	function logic expected_jump_f(logic[31:0] instruction);
		if (instruction[6:0] == JAL || instruction[6:0] == I_TYPE_JALR)
			return 1;
		else
			return 0;
	endfunction

	function logic expected_branch_f(logic[31:0] instruction);
		if (instruction[6:0] == B_TYPE)
			return 1;
		else
			return 0;
	endfunction

	function logic expected_branch_if_zero_f(logic[31:0] instruction);
		if (instruction[14:12] inside { 'b000, 'b011, 'b111 })
			return 1;
		else
			return 0;
	endfunction

	function logic expected_branch_base_f(logic[31:0] instruction);
		if (instruction[6:0] == I_TYPE_JALR)
			return 1;
		else
			return 0;
	endfunction

	function void validate_alu_signals(branch_evaluator_transaction tx);
		logic [2:0] expected_alu_op = expected_alu_op_f(tx.instruction);
		logic expected_sign = expected_sign_f(tx.instruction);
		logic [1:0] expected_op1_src = expected_op1_src_f(tx.instruction);
		logic expected_op2_src = expected_op2_src_f(tx.instruction);

		if (tx.alu_op != expected_alu_op) begin
			`uvm_error("SCOREBOARD", $sformatf("alu_op signal 0x%0h did not match expected value 0x%0h for instruction 0x%0h", tx.alu_op, expected_alu_op, tx.instruction))
		end

		if (tx.sign != expected_sign) begin
			`uvm_error("SCOREBOARD", $sformatf("sign signal 0x%0h did not match expected value 0x%0h for instruction 0x%0h", tx.sign, expected_sign, tx.instruction))
		end

		if (tx.op1_src != expected_op1_src) begin
			`uvm_error("SCOREBOARD", $sformatf("op1_src signal 0x%0h did not match expected value 0x%0h for instruction 0x%0h", tx.op1_src, expected_op1_src, tx.instruction))
		end

		if (tx.op2_src != expected_op2_src) begin
			`uvm_error("SCOREBOARD", $sformatf("op2_src signal 0x%0h did not match expected value 0x%0h for instruction 0x%0h", tx.op2_src, expected_op2_src, tx.instruction))
		end
	endfunction

	function logic[2:0] expected_alu_op_f(logic[31:0] instruction);
		logic [6:0] opcode = instruction[6:0];
		logic [2:0] funct3 = instruction[14:12];

		if (opcode == B_TYPE) begin
			if (funct3 inside { 'b000, 'b001 })
				return 'b000;
			else if (funct3 inside { 'b100, 'b101 })
				return 'b010;
			else if (funct3 inside { 'b110, 'b111 })
				return 'b011;
			else
				`uvm_error("SCOREBOARD", $sformatf("Detected an invalid combination of opcode 0x%0h and funct3 0x%0h", opcode, funct3))
		end
		else if (opcode == LUI || opcode == AUIPC || opcode == I_TYPE_LOAD || opcode == S_TYPE)
			return 'b000;
		else
			return funct3;
	endfunction

	function logic[2:0] expected_sign_f(logic[31:0] instruction);
		logic [6:0] opcode = instruction[6:0];
		logic [2:0] funct3 = instruction[14:12];

		if (opcode == B_TYPE) begin
			if (funct3 inside { 'b000, 'b001 })
				return 1;
			else if (funct3 inside { 'b100, 'b101, 'b110, 'b111 })
				return 0;
			else
			begin
				`uvm_error("SCOREBOARD", $sformatf("Detected an invalid combination of opcode 0x%0h and funct3 0x%0h on instruction 0x%0h", opcode, funct3, instruction))
				return 0;
			end
		end
		else if (opcode == LUI || opcode == AUIPC || opcode == I_TYPE_LOAD || opcode == S_TYPE)
			return 0;
		else if (opcode == R_TYPE && instruction[31:25] == 'b0100000)
			return 1;
		else
			return 0;
	endfunction

	function logic[1:0] expected_op1_src_f(logic[31:0] instruction);
		logic [6:0] opcode = instruction[6:0];

		if (opcode == LUI)
			return 2;
		else if (opcode == AUIPC)
			return 1;
		else
			return 0;
	endfunction

	function logic expected_op2_src_f(logic[31:0] instruction);
		logic [6:0] opcode = instruction[6:0];

		if (opcode inside { I_TYPE_ALU, I_TYPE_LOAD, I_TYPE_JALR, S_TYPE, LUI })
			return 1;
		else
			return 0;
	endfunction

	function void validate_misc_signals(branch_evaluator_transaction tx);
		logic [1:0] expected_rd_select = expected_rd_select_f(tx.instruction);
		logic expected_rf_write_en = expected_rf_write_en_f(tx.instruction);
		logic expected_mem_write_en = expected_mem_write_en_f(tx.instruction);

		if (tx.rd_select != expected_rd_select)
			`uvm_error("SCOREBOARD", $sformatf("rd_select value b%0b did not match expected value b%0b for instruction 0x%0h", tx.rd_select, expected_rd_select, tx.instruction))
		if (tx.rf_write_en != expected_rf_write_en)
			`uvm_error("SCOREBOARD", $sformatf("rf_write_en value b%0b did not match expected value b%0b for instruction 0x%0h", tx.rf_write_en, expected_rf_write_en, tx.instruction))
		if (tx.mem_write_en != expected_mem_write_en)
			`uvm_error("SCOREBOARD", $sformatf("mem_write_en value b%0b did not match expected value b%0b for instruction 0x%0h", tx.mem_write_en, expected_mem_write_en, tx.instruction))
	endfunction

	function logic[1:0] expected_rd_select_f(logic[31:0] instruction);
		logic [6:0] opcode = instruction[6:0];
		
		// rd_select
		if (opcode inside { R_TYPE, I_TYPE_ALU, LUI, AUIPC })
			return 0;
		else if (opcode == I_TYPE_LOAD)
			return 1;
		else if (opcode inside { JAL, I_TYPE_JALR })
			return 2;
		else
			return 0;	// writeback not enabled for these opcodes
	endfunction

	function logic expected_rf_write_en_f(logic[31:0] instruction);
		logic [6:0] opcode = instruction[6:0];
		
		if (opcode inside { LUI, AUIPC, R_TYPE, JAL, I_TYPE_ALU, I_TYPE_LOAD, I_TYPE_JALR })
			return 1;
		else
			return 0;
	endfunction

	function logic expected_mem_write_en_f(logic[31:0] instruction);
		logic [6:0] opcode = instruction[6:0];
		
		if (opcode == S_TYPE)
			return 1;
		else
			return 0;
	endfunction

endclass
