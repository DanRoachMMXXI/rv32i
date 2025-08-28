`include "uvm_macros.svh"
import uvm_pkg::*;

class alu_operand_select_transaction #(parameter XLEN=32) extends uvm_sequence_item;
	`uvm_object_utils(alu_operand_select_transaction)

    // inputs
    rand logic [XLEN-1:0] rs1;
    rand logic [XLEN-1:0] rs2;
    rand logic [XLEN-1:0] immediate;
    rand logic [XLEN-1:0] pc;
    rand logic [1:0] alu_op1_src;
    rand logic alu_op2_src;

    // outputs
    logic [XLEN-1:0] alu_op1;
    logic [XLEN-1:0] alu_op2;

	function new(string name = "");
		super.new(name);
	endfunction
endclass
