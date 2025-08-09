`include "uvm_macros.svh"
import uvm_pkg::*;

class instruction_decode_sequence extends uvm_sequence #(instruction_decode_transaction);
	`uvm_object_utils(instruction_decode_sequence)

	// needs a default name
	function new (string name = "instruction_decode_sequence");
		super.new(name);
	endfunction

	task body;
		// body taken from notes from video
		forever begin
			instruction_decode_transaction tx;
			tx = instruction_decode_transaction#(.XLEN(32))::type_id::create("tx");
			start_item(tx);		// handshake to communicate with driver
			
			// no sim license workaround
			// TODO: change to instruction decode transaction
			tx.a = $urandom();
			tx.b = $urandom();
			tx.op = $urandom_range(0,7);
			if (!(tx.op inside { 3'b000, 3'b101 }))
				tx.sign = 0;
			else
				tx.sign = $urandom_range(0, 1);

			finish_item(tx);	// send transaction to driver
			#1;
		end
	endtask
endclass
