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
			`uvm_info("SCOREBOARD", $sformatf("Immediate value 0x%0h mismatched expected output 0x%0h for instruction 0x%0h", tx.immediate, expected_immediate(tx.instruction), tx.instruction), UVM_NONE)

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
endclass
