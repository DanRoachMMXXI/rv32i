`include "uvm_macros.svh"
import uvm_pkg::*;

import instruction_decode_pkg::*;

class instruction_decode_scoreboard extends uvm_component;	// see if it should be component or scoreboard
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
		// TODO: write validation logic
		logic [31:0] expected_result;
		string msg;
		case ({tx.sign, tx.op})
			4'b0000:	// add
				expected_result = tx.a + tx.b;
			4'b0001:	// left shift
				expected_result = tx.a << tx.b[4:0];
			4'b0010:	// less than signed
				expected_result = ($signed(tx.a) < $signed(tx.b)) ? 1 : 0;
			4'b0011:	// less than unsigned
				expected_result = (tx.a < tx.b) ? 1 : 0;
			4'b0100:	// xor
				expected_result = tx.a ^ tx.b;
			4'b0101:	// logical right shift
				expected_result = tx.a >> tx.b[4:0];
			4'b0110:	// or
				expected_result = tx.a | tx.b;
			4'b0111:	// and
				expected_result = tx.a & tx.b;
			4'b1000:	// sub
				expected_result = tx.a - tx.b;
			4'b1101:	// arithmetic right shift
				expected_result = $signed($signed(tx.a) >>> tx.b[4:0]);
			default:	// throw error here, invalid arg
			begin
				msg = $sformatf("ALU received invalid combination of sign %0d and op %0d", tx.sign, tx.op);
				`uvm_error("SCOREBOARD", msg)
			end
		endcase

		if (tx.result !== expected_result) begin
			msg = $sformatf("ALU output 0x%0h mismatched expected output 0x%0h for sign 0x%0h and op 0x%0h", tx.result, expected_result, tx.sign, tx.op);
			`uvm_error("SCOREBOARD", msg)
		end
		else
		begin
			msg = $sformatf("ALU output 0x%0h matched expected output for sign 0x%0h and op 0x%0h", tx.result, tx.sign, tx.op);
			`uvm_info("SCOREBOARD", msg, UVM_NONE)
		end
	endfunction
endclass
