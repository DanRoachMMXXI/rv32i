`include "uvm_macros.svh"
import uvm_pkg::*;

class alu_sequence extends uvm_sequence #(alu_transaction);
	`uvm_object_utils(alu_sequence)

	// needs a default name
	function new (string name = "alu_sequence");
		super.new(name);
	endfunction

	task body;
		// body taken from notes from video
		// TODO: maybe not forever, ask gpt
		forever begin
			alu_transaction tx;
			tx = alu_transaction#(.XLEN(32))::type_id::create("tx");
			start_item(tx);		// handshake to communicate with driver
			
			// no sim license workaround
			tx.a = $urandom();
			tx.b = $urandom();
			tx.op = $urandom_range(0,7);
			if (!(tx.op inside { 3'b000, 3'b101 }))
				tx.sign = 0;
			else
				tx.sign = $urandom_range(0, 1);

			// assert(tx.randomize());	// initialize tx data
			finish_item(tx);	// send transaction to driver
			#1;
		end
	endtask
endclass
