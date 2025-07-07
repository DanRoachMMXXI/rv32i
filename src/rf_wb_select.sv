module rf_wb_select #(parameter XLEN=32) (
		input logic [XLEN-1:0] alu_result,
		input logic [XLEN-1:0] memory_data_out,
		input logic [XLEN-1:0] pc_plus_four,
		input logic [1:0] select,
		output logic [XLEN-1:0] rd
);
	always_comb
		case (select)
			0:	rd = alu_result;
			1:	rd = memory_data_out;
			2:	rd = pc_plus_four;
		endcase
endmodule
