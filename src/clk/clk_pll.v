module clk_pll(
	input clk,

	input pll_rst,
	output pll_clk_out,
	output pll_locked,

	input config_rst,
	input config_en,
	input [31:0] config_N,
	input [31:0] config_M,
	input [31:0] config_K,
	input [31:0] config_C
);

wire [63:0] reconfig_to_pll, reconfig_from_pll;

reg [3:0] config_state;
reg [1:0] write_state;

wire waitrequest;
wire write = write_state == 1;
reg [5:0] address;
reg [31:0] writedata;

localparam config_data_len = 6;
localparam [38 * config_data_len - 1:0] config_data = {
	6'h00, 32'h0000, // waitrequest mode
	6'h03, 32'h0000, // Filler - N
	6'h04, 32'h0000, // Filler - M
	6'h05, 32'h0000, // Filler - C0
//	6'h06, 32'h0000, // No phase shift
	6'h07, 32'h0000, // Filler - K
//	6'h08, 32'h0006, // Bandwidth
//	6'h09, 32'h0003, // Charge pump current
//	6'h1C, 32'h0001, // VCO DIV = 1
	6'h02, 32'h0001, // Start
};

pll pll(
	.refclk(clk),
	.rst(pll_rst),
	.outclk_0(pll_clk_out),
	.locked(pll_locked),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);

pll_reconfig pll_reconfig(
	.mgmt_clk(clk),
	.mgmt_reset(config_rst),
	.mgmt_waitrequest(waitrequest),
	.mgmt_read(1'b0),
	.mgmt_write(write),
	.mgmt_readdata(),
	.mgmt_address(address),
	.mgmt_writedata(writedata),
	
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);

always @(posedge clk, negedge config_en) begin
	if(!config_en) begin
		config_state <= 0;
		write_state <= 2;
	end
	else if(!waitrequest) begin
		if(write_state == 2) begin
			if(config_state <= config_data_len) begin
				address = config_data[(config_data_len - config_state) * 38 + 32 +: 6];

				if(address == 16'h03)
					writedata <= config_N;
				else if(address == 16'h04)
					writedata <= config_M;
				else if(address == 16'h05)
					writedata <= config_C;
				else if(address == 16'h07)
					writedata <= config_K;
				else
					writedata <= config_data[(config_data_len - config_state) * 38 +: 32];

				config_state = config_state + 4'd1;

				write_state <= 0;
			end
			else
				write_state <= 3;
		end
		else if(write_state < 2)
			write_state <= write_state + 2'd1;
	end
end

endmodule
