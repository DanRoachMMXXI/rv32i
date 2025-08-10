`include "uvm_macros.svh"
import uvm_pkg::*;

import opcode::*;

class instruction_decode_transaction #(parameter XLEN=32) extends uvm_sequence_item;
	`uvm_object_utils(instruction_decode_transaction)

	rand logic [31:0] instruction;

	constraint c_opcode {
		// constrains the opcode to legal opcodes
		instruction[6:0] inside { opcodes };
	}

	constraint c_funct7 {
		// constraint on funct7 for R TYPE instructions
		if (instruction[6:0] == R_TYPE)
			instruction[31] == 1'b0;
		// set instruction[30] based on funct3
		if (instruction[6:0] == R_TYPE && !(instruction[14:12] inside { 3'b000, 3'b101 }))
			instruction[30] == 1'b0;
		if (instruction[6:0] == R_TYPE)
			instruction[29:25] == 5'b00000;
	}

	constraint c_funct3 {
		// I TYPE
		if (instruction[6:0] == I_TYPE_ALU)
			instruction[14:12] inside { 3'b000, 3'b010, 3'b011, 3'b100, 3'b110, 3'b111 };
		if (instruction[6:0] == I_TYPE_LOAD)
			instruction[14:12] inside { 3'b000, 3'b001, 3'b010, 3'b100, 3'b101 };
		if (instruction[6:0] == I_TYPE_JALR)
			instruction[14:12] == 3'b000;

		// B TYPE
		if (instruction[6:0] == B_TYPE)
			instruction[14:12] inside { 3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111 };

		// S TYPE
		if (instruction[6:0] == S_TYPE)
			instruction[14:12] inside { 3'b000, 3'b001, 3'b010 };
	}


	// outputs
	logic [4:0] rs1;
	logic [4:0] rs2;
	logic [4:0] rd;
	logic [XLEN-1:0] immediate;
	logic [1:0] op1_src;
	logic op2_src;
	logic [1:0] rd_select;
	logic [2:0] alu_op;
	logic sign;
	logic branch;
	logic branch_if_zero;
	logic jump;
	logic branch_base;
	logic rf_write_en;
	logic mem_write_en;

	function new(string name = "");
		super.new(name);
	endfunction
endclass
