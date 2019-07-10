/*************************************************************************
  ** Title: uart_tx
  ** Project: Scanner
*************************************************************************
  ** File: uart_tx.v
  ** Author: Zhang Yuming
  ** Created time: 2017/4/26 15:10:04
  ** Last update: 2017/5/10 15:12:38
*************************************************************************
  ** Description:
       This module is data sending logic module of uart communication;
*************************************************************************
  ** Copyright (C) 2017-2027 Hywire instruments,Ltd. All rights reserved.
*************************************************************************/

/*************************************************************************
*************************************************************************
  ** Revisions: 1.0
  ** Update: 2017/4/26 15:10:27
  ** Modifier: Zhang Yuming
  ** Description: 
       Initial version.
*************************************************************************
*************************************************************************/

module uart_tx(
		rst_n,
		baud_clk,
		parity_en,
		write,
		datain,
		tx,		
		idle,
		tx_finish
	);
	input rst_n;
	input baud_clk;		// sampling clk, 16 x baud rate
	input parity_en;	// enable parity bit
	input write;		// data transmit trigger
	input [7:0] datain;	// data transmit input
	
	reg [7:0] write_reg;
	output reg tx;
	output reg idle;
	output reg tx_finish;
	
	reg idle_d;
	
	reg write_d;
	reg write_rise;
	reg send_start;
	reg parity_bit;
	reg [7:0] clk_cnt;
	
	always @(posedge baud_clk or negedge rst_n) 
	begin
		if(!rst_n)
		begin
			write_d <= 0;
			write_rise <= 0;
		end
		else
		begin
			write_d <= write;
			write_rise <= (~write_d) & write;
		end
	end

	always @(posedge baud_clk or negedge rst_n)
	begin
		if(!rst_n)
		begin
			send_start <= 1'b0;
		end
		else
		begin
			if (write_rise && (idle))		// data transmit trigger valid while idle, start transmitting process
			begin
				send_start <= 1'b1;
				write_reg <= datain;
			end
			else if(clk_cnt >= 8'd168)		// transmit finished
			begin
				send_start <= 1'b0; 
			end
		end
	end

	always @(posedge baud_clk or negedge rst_n)
	begin
		if(!rst_n)
		begin
			tx_finish <= 0;
			idle_d <= 1;
		end
		else
		begin
			idle_d <= idle;
			if(idle & !idle_d)
			begin
				tx_finish <= 1;
			end
			else
			begin
				tx_finish <= 0;
			end
		end
	end

	always @(posedge baud_clk or negedge rst_n)
	begin
		if(!rst_n)
		begin
			tx <= 1;
			parity_bit <= 0;
			idle <= 1'b1;
			clk_cnt <= 8'd0;
		end
		else
		begin
			if(send_start == 1'b1)
			begin
			case(clk_cnt)   
				8'd0:	// generate start bit
				begin  
					tx <= 1'b0;
					idle <= 1'b0;
					clk_cnt <= clk_cnt + 8'd1;
				end 
				8'd16:	// transmit bit 0
				begin
					tx <= write_reg[0];
					parity_bit <= write_reg[0]^parity_en;
					idle <= 1'b0;
					clk_cnt <= clk_cnt + 8'd1;
				end
				8'd32:	// transmit bit 1
				begin
					tx <= write_reg[1];
					parity_bit <= write_reg[1]^parity_bit; 
					idle <= 1'b0;
					clk_cnt <= clk_cnt + 8'd1;
				end
				8'd48:	// transmit bit 2
				begin  
					tx <= write_reg[2];
					parity_bit <= write_reg[2]^parity_bit; 
					idle <= 1'b0;
					clk_cnt <= clk_cnt + 8'd1;
				end
				8'd64:	// transmit bit 3
				begin
					tx <= write_reg[3];
					parity_bit <= write_reg[3]^parity_bit; 
					idle <= 1'b0;
					clk_cnt <= clk_cnt + 8'd1;
				end
				8'd80:	// transmit bit 4
				begin
					tx <= write_reg[4];
					parity_bit <= write_reg[4]^parity_bit; 
					idle <= 1'b0;
					clk_cnt <= clk_cnt + 8'd1; 
				end
				8'd96:	// transmit bit 5
				begin
					tx <= write_reg[5];
					parity_bit <= write_reg[5]^parity_bit; 
					idle <= 1'b0;
					clk_cnt <= clk_cnt + 8'd1;
				end
				8'd112:	// transmit bit 6
				begin
					tx <= write_reg[6];
					parity_bit <= write_reg[6]^parity_bit; 
					idle <= 1'b0;
					clk_cnt <= clk_cnt + 8'd1;
				end
				8'd128:	// transmit bit 7
				begin  
					tx <= write_reg[7];
					parity_bit <= write_reg[7]^parity_bit;
					idle <= 1'b0;
					clk_cnt <= clk_cnt + 8'd1;
				end
				8'd144:	// transmit parity_bit/stop_bit
				begin
					if(parity_en)
					begin
						tx <= parity_bit;
						parity_bit <= write_reg[0]^parity_en;
						idle <= 1'b0;
						clk_cnt <= clk_cnt + 8'd1;
					end
					else
					begin
						tx <= 1'b1;
						idle <= 1'b0;
						clk_cnt <= 8'd 161;
					end
				end
				8'd160:	// transmit stop_bit
				begin
					tx <= 1'b1;
					idle <= 1'b0;
					clk_cnt <= clk_cnt + 8'd1;
				end
				8'd176:	// transmit finished
				begin
					tx <= 1'b1; 
					idle <= 1'b1;
					clk_cnt <= clk_cnt + 8'd1;
				end
				default:
				begin
					clk_cnt <= clk_cnt + 8'd1;
				end
			endcase
			end
			else
			begin
				tx <= 1'b1;
				clk_cnt <= 8'd0;
				idle <= 1'b1; 
			end
		end
	end
	
endmodule
