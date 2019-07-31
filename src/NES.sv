module NES(
    output            ADC_CONVST,
    output            ADC_SCK,
    output            ADC_SDI,
    input             ADC_SDO,

    inout      [15:0] ARDUINO_IO,
    inout             ARDUINO_RESET_N,

    input             FPGA_CLK1_50,
    input             FPGA_CLK2_50,
    input             FPGA_CLK3_50,

    inout             HDMI_I2C_SCL,
    inout             HDMI_I2C_SDA,
    inout             HDMI_I2S,
    inout             HDMI_LRCLK,
    inout             HDMI_MCLK,
    inout             HDMI_SCLK,
    output            HDMI_TX_CLK,
    output reg        HDMI_TX_DE,
    output reg [23:0] HDMI_TX_D,
    output reg        HDMI_TX_HS,
    input             HDMI_TX_INT,
    output reg        HDMI_TX_VS,

    input       [1:0] KEY,
    output      [7:0] LED,
    input       [3:0] SW,

    inout      [35:0] GPIO_0,
    inout      [35:0] GPIO_1
);

wire main_clk;

wire i2c_clk2;
assign main_clk = FPGA_CLK1_50;

wire hdmi_en;
assign hdmi_en = SW[0];

wire pixclk;
wire pixclk_locked;
wire hdmi_out_en;

reg [15:0] h_active = 1920, hs_start = 2008, hs_end = 2052, h_total = 2200;
reg [15:0] v_active = 1080, vs_start = 1084, vs_end = 1089, v_total = 1125;
//reg [15:0] h_active = 960, hs_start = 1004, hs_end = 1026, h_total = 1100;
//reg [15:0] v_active = 540, vs_start = 542, vs_end = 545, v_total = 560;

reg [15:0] pix2_x = 0, pix2_y = 0;
reg [15:0] pix1_x = 0, pix1_y = 0;
reg [15:0] pix0_x = 0, pix0_y = 0;

reg [63:0] frame2_ctr;
reg [63:0] frame1_ctr;
reg [63:0] frame0_ctr;

reg [15:0] fb_width = 256, fb_height = 240;
reg [1:0] scale = 2;

wire [15:0] view_width = fb_width << scale;
wire [15:0] view_height = fb_height << scale;

wire [15:0] offset_x = 0;//(h_active - view_width) / 2;
wire [15:0] offset_y = 0;//(v_active - view_height) / 2;

//always @(posedge KEY[0])
//	scale <= scale + 1;

clk_pll pll_pixclk(
	.clk(main_clk),

	.pll_rst(!hdmi_en),
	.pll_clk_out(pixclk),
	.pll_locked(pixclk_locked),

	.config_rst(~hdmi_en),
	.config_en(hdmi_en),
	.config_N(32'h1_00_00),
	.config_M(32'h2_09_08),
	.config_K(3521873183),
	.config_C(32'h0_03_03)
);

wire i2s_clk;
wire i2s_locked;
reg i2s;

clk_pll pll_i2sclk(
	.clk(main_clk),

	.pll_rst(!hdmi_en),
	.pll_clk_out(i2s_clk),
	.pll_locked(i2s_locked),

	.config_rst(~hdmi_en),
	.config_en(hdmi_en),
	.config_N(32'h1_00_00),
	.config_M(32'h2_08_07),
	.config_K(3129484971),
	.config_C(32'h0_80_80)
);

reg [5:0] i2s_state;

wire [15:0] audio_left;
wire [15:0] audio_right;
wire [15:0] audio_sample_nes, audio_sample;

assign HDMI_LRCLK = i2s_state[5];
assign HDMI_SCLK = ~i2s_clk;
assign HDMI_I2S = i2s;

clk_sync #(32) sync(
	.clk_i(nes_clk),
	.dat_i(audio_sample_nes),
	.clk_o(~HDMI_LRCLK),
	.dat_o(audio_sample)
);

always @(posedge i2s_clk) begin
	i2s_state = i2s_state + 6'd1;
	if((1 <= i2s_state) & (i2s_state < 17))
		i2s = audio_left[16 - i2s_state];
	else if((33 <= i2s_state) & (i2s_state < 49))
		i2s = audio_right[48 - i2s_state];
end

clk_divider i2c_clk_gen(
	.reset(KEY[1]),
	.factor(125),
	.clk_in(main_clk),
	.clk_out(i2c_clk2)
);

assign audio_left = {~audio_sample[15], audio_sample[14:0]};
assign audio_right = {~audio_sample[15], audio_sample[14:0]};

hdmi_config hdmi_cfg(
	.enable(~KEY[1]),
	.i2c_clk2(i2c_clk2),
	.i2c_sda(HDMI_I2C_SDA),
	.i2c_scl(HDMI_I2C_SCL),
	.i2c_nack()
);

assign hdmi_out_en = hdmi_en & pixclk_locked;
assign HDMI_TX_CLK = ~pixclk & hdmi_out_en;

assign LED[7] = HDMI_TX_VS;
assign LED[6] = HDMI_TX_HS;
assign LED[5] = HDMI_TX_DE;

wire [5:0] fb1_clr;
reg [5:0] fb0_clr;

wire [15:0] addr = ((pix2_y - offset_y) >> scale) * fb_width + ((pix2_x - offset_x) >> scale);

wire [5:0] color;
wire [8:0] cycle;
wire [8:0] scanline;

wire [15:0] fb_w_addr = scanline * fb_width + cycle;
wire fb_w = (cycle < fb_width) & (scanline < fb_height);

framebuffer fb(
	.rdclock(HDMI_TX_CLK),
	.rdaddress(addr < (fb_width * fb_height) ? addr : 0),
	.q(fb1_clr),

	.wrclock(nes_clk),
	.wraddress(fb_w_addr),
	.wren(fb_w),
	.data(color)
);

reg [8:0] clr_lookup [64] = '{
	9'o333, 9'o014, 9'o006, 9'o326, 9'o403, 9'o503, 9'o510, 9'o420, 9'o320, 9'o120, 9'o031, 9'o040, 9'o022, 9'o000, 9'o000, 9'o000,
	9'o555, 9'o036, 9'o027, 9'o407, 9'o507, 9'o704, 9'o700, 9'o630, 9'o430, 9'o140, 9'o040, 9'o053, 9'o044, 9'o000, 9'o000, 9'o000,
	9'o777, 9'o357, 9'o447, 9'o637, 9'o707, 9'o737, 9'o740, 9'o750, 9'o660, 9'o360, 9'o070, 9'o276, 9'o077, 9'o000, 9'o000, 9'o000,
	9'o777, 9'o567, 9'o657, 9'o757, 9'o747, 9'o755, 9'o764, 9'o772, 9'o773, 9'o572, 9'o473, 9'o276, 9'o467, 9'o000, 9'o000, 9'o000
};

always @(posedge HDMI_TX_CLK, negedge hdmi_en) begin
	if(!hdmi_en) begin
		pix2_x <= 0;
		pix2_y <= 0;
		pix1_x <= 0;
		pix1_y <= 0;
		pix0_x <= 0;
		pix0_y <= 0;

		frame2_ctr <= 0;
		frame1_ctr <= 0;
		frame0_ctr <= 0;

		HDMI_TX_D <= 0;
		HDMI_TX_DE <= 0;
		HDMI_TX_HS <= 0;
		HDMI_TX_VS <= 0;
	end
	else begin
		reg x_wrap, y_wrap;
		reg [8:0] clr;

		if((offset_x <= pix0_x) & (pix0_x < offset_x + view_width) & (offset_y <= pix0_y) & (pix0_y < offset_y + view_height)) begin
			HDMI_TX_D = 0;
			clr = clr_lookup[fb0_clr];
			HDMI_TX_D[23:21] = clr[8:6];
			HDMI_TX_D[15:13] = clr[5:3];
			HDMI_TX_D[7:5] = clr[2:0];
		end
		else begin
			HDMI_TX_D[23:16] = pix0_x + frame0_ctr;
			HDMI_TX_D[15:8] = pix0_y + frame0_ctr * 2;
			HDMI_TX_D[7:0] = pix0_x / 4;
		end

		HDMI_TX_DE = (pix0_x < h_active) & (pix0_y < v_active);
		HDMI_TX_HS = (hs_start <= pix0_x) & (pix0_x < hs_end);
		HDMI_TX_VS = (vs_start <= pix0_y) & (pix0_y < vs_end);

		fb0_clr = fb1_clr;

		pix0_x = pix1_x;
		pix0_y = pix1_y;
		frame0_ctr = frame1_ctr;

		pix1_x = pix2_x;
		pix1_y = pix2_y;
		frame1_ctr = frame2_ctr;

		x_wrap = pix2_x == h_total - 1;
		y_wrap = pix2_y == v_total - 1 & x_wrap;

		pix2_x = x_wrap ? 0 : pix2_x + 1;
		pix2_y = y_wrap ? 0 : x_wrap ? pix2_y + 1 : pix2_y; 
		frame2_ctr = frame2_ctr + y_wrap;
	end
end

wire nes_clk;
wire nes_clk_locked;
wire nes_rst = ~KEY[0];
wire nes_en = nes_clk_locked;

wire nes_mem_clk = ~nes_clk;

clk_pll pll_nesclk(
	.clk(main_clk),

	.pll_rst(SW[1]),
	.pll_clk_out(nes_clk),
	.pll_locked(nes_clk_locked),

	.config_rst(SW[1]),
	.config_en(~SW[1]),
	.config_N(32'h1_00_00),
	.config_M(32'h0_0A_0A),
	.config_K(2509470364),
	.config_C(32'h0_60_60)
);


wire [15:0] prg_addr;
wire prg_r, prg_w;
wire [7:0] prg_r_data, prg_w_data;

wire [13:0] chr_addr;
wire chr_r, chr_w;
wire [7:0] chr_r_data, chr_w_data;

rom_prg rprg(
	.clock(nes_mem_clk & nes_en),
	.address(prg_addr),
	.data(prg_w_data),
	.wren(prg_w),
	.q(prg_r_data)
);
rom_chr rchr(
	.clock(nes_mem_clk & nes_en),
	.address(chr_addr),
	.data(chr_w_data),
	.wren(chr_w),
	.q(chr_r_data)
);

nes nes(
	.rst(nes_rst),
	.clk(nes_clk),
	.enable(nes_en),

	.prg_addr(prg_addr),
	.prg_r(prg_r),
	.prg_w(prg_w),
	.prg_r_data(prg_r_data),
	.prg_w_data(prg_w_data),

	.chr_addr(chr_addr),
	.chr_r(chr_r),
	.chr_w(chr_w),
	.chr_r_data(chr_r_data),
	.chr_w_data(chr_w_data),
	
	.joy_a({GPIO_0[15], GPIO_0[13], GPIO_0[11], GPIO_0[9], GPIO_0[7], GPIO_0[5], GPIO_0[3], GPIO_0[1]}),

	.pix_color(color),
	.pix_x(cycle),
	.pix_y(scanline),

	.audio_sample(audio_sample_nes)
);

endmodule
