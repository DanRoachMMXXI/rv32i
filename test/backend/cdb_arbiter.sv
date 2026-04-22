module test_cdb_arbiter;
	logic [15:0] request;
	logic [15:0] grant;
	logic cdb_active;

	cdb_arbiter #(.N(16)) cdb_arbiter (
		.request(request),
		.grant(grant),
		.cdb_active(cdb_active)
		);

	initial begin
		request = 0;
		# 1
		display_signals();

		request = 1;
		# 1
		display_signals();

		request = 7;
		# 1
		display_signals();

		request = 9;
		# 1
		display_signals();

		request = 'hFFFF;
		# 1
		display_signals();
	end

	task display_signals();
		$display("request:\t%b", request);
		$display("grant:\t\t%b", grant);
		$display("cdb_active: %d", cdb_active);
	endtask
endmodule
