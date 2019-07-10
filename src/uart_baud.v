/*************************************************************************
  ** Title: uart_baud
  ** Project: ALF
*************************************************************************
  ** File: uart_baud.v
  ** Author: Zhang Yuming
  ** Created time: 2017/4/25 19:20:04
  ** Last update: 2019/6/16 17:22:38
*************************************************************************
  ** Description:
       This module is baud rate clock generator for uart communication;
       The baud_clk frequency is 16 times of baud rate;
*************************************************************************
  ** Copyright (C) 2017-2027 Hywire instruments,Ltd. All rights reserved.
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

module uart_baud(
		clk,
		rst_n,
		baud_clk		// 16 x baudrate
	);
	input clk, rst_n;
	output reg baud_clk;		// 16 x baudrate
	reg [31:0] clk_cnt;
	
	parameter CLK_FREQ = 32'd 50_000_000;		// clk frequency, default as 50 MHz
	parameter BAUDRATE = 32'd 9600;
	parameter BAUDRATE_CLKCNT = CLK_FREQ/(BAUDRATE*16);
	parameter BAUDRATE_CLKCNT_2 = BAUDRATE_CLKCNT/2;
	
	always @ (posedge clk or negedge rst_n)
	begin
		if(!rst_n)
		begin
			clk_cnt <= 32'd 0;
			baud_clk <= 0;
		end
		else
		begin
			if(clk_cnt == BAUDRATE_CLKCNT_2 - 32'd 1)
			begin
				baud_clk <= 1;
				clk_cnt <= clk_cnt + 32'd 1;
			end
			else if(clk_cnt == BAUDRATE_CLKCNT - 32'd 1)
			begin
				baud_clk <= 0;
				clk_cnt <= 32'd 0;
			end
			else
			begin
				clk_cnt <= clk_cnt + 32'd 1;
			end
		end
	end
	
endmodule
