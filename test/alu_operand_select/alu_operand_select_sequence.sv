`include "uvm_macros.svh"
import uvm_pkg::*;

class alu_operand_select_sequence extends uvm_sequence #(alu_operand_select_transaction);
	`uvm_object_utils(alu_operand_select_sequence)

	// needs a default name
	function new (string name = "alu_operand_select_sequence");
		super.new(name);
	endfunction

	task body;
		forever begin
			alu_operand_select_transaction tx;
			tx = alu_operand_select_transaction#(.XLEN(32))::type_id::create("tx");
			start_item(tx);		// handshake to communicate with driver
			
			// no sim license workaround

			tx.rs1 = $urandom_range(0, (2<<32)-1);	// TODO parameterize by XLEN
			tx.rs2 = $urandom_range(0, (2<<32)-1);
			tx.immediate = $urandom_range(0, (2<<32)-1);
			tx.pc = $urandom_range(0, (2<<32)-1);
			tx.alu_op1_src = $urandom_range(0, 2);
			tx.alu_op2_src = $urandom_range(0, 1);

			finish_item(tx);	// send transaction to driver
			#1;
		end
	endtask
endclass
