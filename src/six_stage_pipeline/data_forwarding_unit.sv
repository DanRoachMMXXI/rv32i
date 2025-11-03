// NOTE: THIS CAN FORWARD A NONZERO VALUE TO THE ZERO REGISTER
// TODO: FIX ^
module data_forwarding_unit #(parameter XLEN=32) (
	input logic [XLEN-1:0] EX_alu_result,
	input logic [1:0] EX_rd_select,
	input logic [4:0] EX_rd_index,
	input logic EX_rf_write_en,

	input logic [XLEN-1:0] DM_alu_result,
	input logic [XLEN-1:0] DM_memory_data_out,
	input logic [1:0] DM_rd_select,
	input logic [4:0] DM_rd_index,
	input logic DM_rf_write_en,

	input logic [XLEN-1:0] WB_rd,
	input logic [4:0] WB_rd_index,
	input logic WB_rf_write_en,

	input logic [XLEN-1:0] register_file_rs,
	input logic [4:0] register_file_rs_index,

	output logic [XLEN-1:0] rs
	);

	// Need to prioritize forwarding from the earlier stages in the
	// pipeline (EX) down to the latter stages (WB)
	always begin
		// EX stage forwarding
		if (register_file_rs_index == EX_rd_index && EX_rf_write_en && EX_rd_select == 0)
			rs = EX_alu_result;
		// DM stage forwarding
		else if (register_file_rs_index == DM_rd_index && DM_rf_write_en && DM_rd_select == 0)
				rs = DM_alu_result;
		else if (register_file_rs_index == DM_rd_index && DM_rf_write_en && DM_rd_select == 1)
				rs = DM_memory_data_out;
		// WB stage forwarding
		else if (register_file_rs_index == WB_rd_index && WB_rf_write_en)
			// no selection logic, just using the value that's
			// already selected to be written to the RF by the
			// rf_wb_select
			rs = WB_rd;
		else
			rs = register_file_rs;
	end
endmodule
