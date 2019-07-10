/*************************************************************************
  ** Title: Top level entity of the project
  ** Project: ALF
*************************************************************************
  ** File: motion_controller.v
  ** Author: Zhang Yuming
  ** Created time: 2019/6/16 10:05
  ** Last update: 2019/6/18 22:18
*************************************************************************
  ** Description:
       This module is top of the project, it defines input/output pins and sub modules;
*************************************************************************
  ** Copyright (C) 2019-2029 Hywire instruments,Ltd. All rights reserved.
*************************************************************************/

/*************************************************************************
*************************************************************************
  ** Revisions: 1.0
  ** Update: 2017/5/9 17:26:27
  ** Modifier: Zhang Yuming
  ** Description: 
       Initial version.
*************************************************************************
*************************************************************************/

module motion_controller(
		clk_in,
		rst_in,
		rst_in2,
		
		sys_error,
		
		uart_tx,
		uart_rx,
		
		motor_fwd_limit_x,
		motor_rvs_limit_x,
		motor_home_x,
		motor_clk_x,
		motor_dir_x,
		motor_fwd_limit_y,
		motor_rvs_limit_y,
		motor_home_y,
		motor_clk_y,
		motor_dir_y,
		motor_fwd_limit_z,
		motor_rvs_limit_z,
		motor_home_z,
		motor_clk_z,
		motor_dir_z,
		motor_fwd_limit_w,
		motor_rvs_limit_w,
		motor_home_w,
		motor_clk_w,
		motor_dir_w,
		
		led1,
		led2,
		led3,
		led4
	);
	input clk_in;
	input rst_in;
	input rst_in2;
	
	output sys_error;
	
	output uart_tx;
	input uart_rx;
	
	input motor_fwd_limit_x;
	input motor_rvs_limit_x;
	input motor_home_x;
	output motor_clk_x;
	output motor_dir_x;
	input motor_fwd_limit_y;
	input motor_rvs_limit_y;
	input motor_home_y;
	output motor_clk_y;
	output motor_dir_y;
	input motor_fwd_limit_z;
	input motor_rvs_limit_z;
	input motor_home_z;
	output motor_clk_z;
	output motor_dir_z;
	input motor_fwd_limit_w;
	input motor_rvs_limit_w;
	input motor_home_w;
	output motor_clk_w;
	output motor_dir_w;
		
	output reg led1;
	output reg led2;
	output led3;
	output led4;
	
	wire sys_rst_n;
	assign sys_rst_n = rst_in & rst_in2 & pll_locked;
	
	assign sys_error = 0;
	
	wire pll_clk;
	wire sys_clk;
	wire mtn_servo_clk;
	wire baud_clk;
	wire pll_locked;
	
	wire uart_cs;
	wire uart_rd;
	wire [7:0] uart_data;
	wire uart_got_data;
	wire uart_tx_finish;
	
	reg [31:0] firmware_ver = {8'd 1, 8'd 0, 8'd 0, 8'd 0};
	
	//====== system clock defination ======//
	parameter SYS_CLK_FREQ = 32'd 40_000_000;
	sys_pll pll_inst(
		.inclk0(clk_in),
		.c0(pll_clk),			// 40 MHz
		.c1(mtn_servo_clk),	// 10 kHz
		.locked(pll_locked)
	);
	clk_mng clk_inst(
		.inclk(pll_clk),
		.outclk(sys_clk)
	);
	
	//====== communication modules ======//
	defparam uart_inst.CLK_FREQ = SYS_CLK_FREQ;
	uart_transceiver uart_inst(
		.clk(sys_clk),
		.rst(sys_rst_n),
		
		.rx(uart_rx),
		.tx(uart_tx),
		
		.baud_clk(baud_clk),
		.cs_n(uart_cs),
		.rd_n(uart_rd),
		.data(uart_data),
		.got_data(uart_got_data),
		.tx_idle(),
		.tx_ok(uart_tx_finish)
	);
	
	wire [7:0] motor_addr;
	wire [31:0] motor_data;
	wire motor_cs_x;
	wire motor_rd_x;
	wire motor_oe_x;
	wire motor_cs_y;
	wire motor_rd_y;
	wire motor_oe_y;
	wire motor_cs_z;
	wire motor_rd_z;
	wire motor_oe_z;
	wire motor_cs_w;
	wire motor_rd_w;
	wire motor_oe_w;
	
	wire motor_at_home_x;
	wire motor_at_fwd_limit_x;
	wire motor_at_bwd_limit_x;
	wire motor_is_busy_x;
	wire motor_is_enabled_x;
	wire motor_at_home_y;
	wire motor_at_fwd_limit_y;
	wire motor_at_bwd_limit_y;
	wire motor_is_busy_y;
	wire motor_is_enabled_y;
	wire motor_at_home_z;
	wire motor_at_fwd_limit_z;
	wire motor_at_bwd_limit_z;
	wire motor_is_busy_z;
	wire motor_is_enabled_z;
	wire motor_at_home_w;
	wire motor_at_fwd_limit_w;
	wire motor_at_bwd_limit_w;
	wire motor_is_busy_w;
	wire motor_is_enabled_w;
	
	protocol protocol_inst(
		.clk(sys_clk),
		.rst(sys_rst_n),
		.baud_clk(baud_clk),
		
		.uart_cs(uart_cs),
		.uart_rd(uart_rd),
		.uart_data(uart_data),
		.uart_got_data(uart_got_data),
		.uart_tx_finish(uart_tx_finish),
		
		.motor_addr(motor_addr),
		.motor_data(motor_data),
		.motor_cs_x(motor_cs_x),
		.motor_rd_x(motor_rd_x),
		.motor_oe_x(motor_oe_x),
		.motor_cs_y(motor_cs_y),
		.motor_rd_y(motor_rd_y),
		.motor_oe_y(motor_oe_y),
		.motor_cs_z(motor_cs_z),
		.motor_rd_z(motor_rd_z),
		.motor_oe_z(motor_oe_z),
		.motor_cs_w(motor_cs_w),
		.motor_rd_w(motor_rd_w),
		.motor_oe_w(motor_oe_w),

		.motor_enabled_x(motor_is_enabled_x),
		.motor_home_x(motor_at_home_x),
		.motor_fwd_limit_x(motor_at_fwd_limit_x),
		.motor_bwd_limit_x(motor_at_bwd_limit_x),
		.motor_busy_x(motor_is_busy_x),
		.motor_enabled_y(motor_is_enabled_y),
		.motor_home_y(motor_at_home_y),
		.motor_fwd_limit_y(motor_at_fwd_limit_y),
		.motor_bwd_limit_y(motor_at_bwd_limit_y),
		.motor_busy_y(motor_is_busy_y),
		.motor_enabled_z(motor_is_enabled_z),
		.motor_home_z(motor_at_home_z),
		.motor_fwd_limit_z(motor_at_fwd_limit_z),
		.motor_bwd_limit_z(motor_at_bwd_limit_z),
		.motor_busy_z(motor_is_busy_z),
		.motor_enabled_w(motor_is_enabled_w),
		.motor_home_w(motor_at_home_w),
		.motor_fwd_limit_w(motor_at_fwd_limit_w),
		.motor_bwd_limit_w(motor_at_bwd_limit_w),
		.motor_busy_w(motor_is_busy_w)
	);
	
	// motion control modules
	motor_control xmotor_inst(
		.clk_40MHz(sys_clk),
		.clk_10kHz(mtn_servo_clk),
		.rst(sys_rst_n),
		.reg_addr(motor_addr),
		.data_bus(motor_data),
		.rdwr(motor_rd_x),
		.cs(motor_cs_x),
		.oe(motor_oe_x),
		
		.m_clk(motor_clk_x),
		.m_dir(motor_dir_x),
		.m_enable(motor_is_enabled_x),
		.m_home(motor_home_x),
		.m_fwd_limit(motor_fwd_limit_x),
		.m_bwd_limit(1'b 0),
		
		.m_at_home(motor_at_home_x),
		.m_at_fwd_limit(motor_at_fwd_limit_x),
		.m_at_bwd_limit(motor_at_bwd_limit_x),
		.m_busy(motor_is_busy_x)
	);
	
	
	//====== debug mode only ======//
	reg [31:0] clk_cnt;
	always @ (posedge sys_clk or negedge sys_rst_n)
	begin
		if(!sys_rst_n)
		begin
			clk_cnt <= 32'd 1;
			led1 <= 0;
			led2 <= 0;
		end
		else
		begin
			if(clk_cnt >= SYS_CLK_FREQ>>1)
			begin
				clk_cnt <= 32'd 1;
				led1 <= ~led1;
				led2 <= ~led2;
			end
			else
			begin
				clk_cnt <= clk_cnt + 32'd 1;
			end
		end
	end
	
endmodule
