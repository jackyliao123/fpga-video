module hdmi_config(
	input enable,
	input i2c_clk2,
	output [2:0] i2c_nack,
	inout i2c_sda,
	inout i2c_scl
);

parameter [6:0] I2C_ADDR = 7'h39;

localparam REG_ENTRIES = 19;

localparam [REG_ENTRIES * 16 - 1:0] REG_WRITES = {
	16'h41_10,
	16'h98_03,
	16'h9A_E0,
	16'h9C_30,
	16'h9D_01,
	16'hA2_A4,
	16'hA3_A4,
	16'hE0_D0,
	16'hF9_00,
	16'h15_30,
	16'h16_30,
	16'h17_02,
	16'h18_00,
	16'hAF_06,
	16'h01_00,
	16'h02_18,
	16'h03_00,
	16'h0C_3C,
	16'h0A_00,
};

reg i2c_en;
wire i2c_done;

reg [7:0] i2c_wr_ind;
reg [15:0] i2c_data;

i2c_write16 i2c(
	.clk2(i2c_clk2),
	.enable(i2c_en),
	.done(i2c_done),
	.addr(I2C_ADDR),
	.data(i2c_data),
	.nack(i2c_nack),
	.sda(i2c_sda),
	.scl(i2c_scl)
);

reg i2c_state;

localparam I2C_STATE_DELAY = 1'b0;
localparam I2C_STATE_START = 1'b1;

always @(negedge i2c_clk2, negedge enable) begin
	if(!enable) begin
		i2c_state <= I2C_STATE_DELAY;
		i2c_wr_ind <= 0;
		i2c_en <= 0;
	end
	else if(i2c_state == I2C_STATE_DELAY) begin
		i2c_en <= 0;
		if(i2c_wr_ind < REG_ENTRIES) begin
			i2c_state <= I2C_STATE_START;
			i2c_data = REG_WRITES[(REG_ENTRIES - 1 - i2c_wr_ind) * 16 +: 16];
		end
	end
	else if(i2c_state == I2C_STATE_START) begin
		i2c_en <= 1;
		if(i2c_done) begin
			i2c_state = I2C_STATE_DELAY;
			i2c_wr_ind <= i2c_wr_ind + 8'd1;
		end
	end
end

endmodule
