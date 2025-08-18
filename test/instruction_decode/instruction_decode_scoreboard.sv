`include "uvm_macros.svh"
import uvm_pkg::*;

import instruction_decode_pkg::*;

import opcode::*;

class instruction_decode_scoreboard #(parameter XLEN=32) extends uvm_component;
	`uvm_component_utils(instruction_decode_scoreboard)

	uvm_analysis_imp #(instruction_decode_transaction, instruction_decode_scoreboard) analysis_export;
	// no need for the expected state here, it's a combinational component
	
	function new(string name, uvm_component parent);
		super.new(name, parent);
		analysis_export = new("analysis_export", this);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
	endfunction

	function void write(instruction_decode_transaction tx);
		// TODO figure out why instruction is always X
		if (!validate_immediate(tx.instruction, tx.immediate))
			`uvm_error("SCOREBOARD", $sformatf("Immediate value 0x%0h mismatched expected output 0x%0h for instruction 0x%0h", tx.immediate, expected_immediate(tx.instruction), tx.instruction))
		else
			`uvm_info("SCOREBOARD", $sformatf("Immediate value 0x%0h matched expected output for instruction 0x%0h", tx.immediate, tx.instruction), UVM_NONE)

		// TODO add validation logic for other decode signals
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
	function logic validate_branch_signals(logic[31:0] instruction);
		// Rather than just &&ing these together, checking them
		// individually to allow me to log the actual signal the
		// validation failed on.
		logic valid = 1;
		if (!validate_jump(instruction)) begin
			`uvm_error("SCOREBOARD", $sformatf("jump signal %d did not match the expected value %d for instruction 0x%0h", tx.jump, expected_jump(instruction), tx.instruction))
			valid = 0;
		end

		if (!validate_branch(instruction)) begin
			`uvm_error("SCOREBOARD", $sformatf("branch signal %d did not match the expected value %d for instruction 0x%0h", tx.branch, expected_branch(instruction), tx.instruction))
			valid = 0;
		end

		if (!validate_branch_if_zero(instruction)) begin
			`uvm_error("SCOREBOARD", $sformatf("branch_if_zero signal %d did not match the expected value %d for instruction 0x%0h", tx.branch_if_zero, expected_branch_if_zero(instruction), tx.instruction))
			valid = 0;
		end

		if (!validate_branch_base(instruction)) begin
			`uvm_error("SCOREBOARD", $sformatf("branch_base signal %d did not match the expected value %d for instruction 0x%0h", tx.branch_base, expected_branch_base(instruction), tx.instruction))
			valid = 0;
		end

		return valid;
	endfunction
endclass
