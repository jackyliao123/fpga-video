module clk_divider (
	input reset,
	input [31:0] factor,
	input clk_in,
	output clk_out
);

reg [31:0] ctr_p;
reg [31:0] ctr_n;
reg out_p;
reg out_n;

assign clk_out = out_p ^ out_n;

always @(posedge clk_in, posedge reset) begin
	if(reset) begin
		ctr_p <= 0;
		out_p <= 0;
	end
	else begin
		ctr_p = ctr_p + 1;
		if(ctr_p + ctr_n >= factor) begin
			ctr_p <= -ctr_n;
			out_p <= ~out_p;
		end
	end
end

always @(negedge clk_in, posedge reset) begin
	if(reset) begin
		ctr_n <= 0;
		out_n <= 0;
	end
	else begin
		ctr_n = ctr_n + 1;
		if(ctr_p + ctr_n >= factor) begin
			ctr_n <= -ctr_p;
			out_n <= ~out_n;
		end
	end
end

endmodule
