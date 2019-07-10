/*************************************************************************
  ** Title: uart_rx
  ** Project: ALF
*************************************************************************
  ** File: uart_rx.v
  ** Author: Zhang Yuming
  ** Created time: 2017/4/26 15:10:04
  ** Last update: 2017/5/10 15:12:38
*************************************************************************
  ** Description:
       This module is data receiving logic module of uart communication;
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

module uart_rx(
		rst_n,
		baud_clk,
		rx,
		parity_en,
		data_out,
		data_rcvd,
		dataerror,
		frameerror
	);

	input rst_n;
	input baud_clk;		// sampling clk, 16 x baud rate
	input rx;			// UART data input
	input parity_en;	// enable parity bit

	output reg [7:0] data_out;	// UART received data output
	output reg data_rcvd;		// data received flag
	output reg dataerror;   	// data error flag
	output reg frameerror;		// UART frame error flag

	reg [7:0] clk_cnt;		// clk counter in receiving process
	reg rx_d, rxfall, receive;  

	reg parity_bit;
	reg idle;  

	// detect falling edge of rx
	always @(posedge baud_clk or negedge rst_n)
	begin
		if(!rst_n)
		begin
			rx_d <= 0;
			rxfall <= 0;
		end
		else
		begin
			rx_d <= rx;
			rxfall <= rx_d & (~rx);
		end
	end  

	always @(posedge baud_clk or negedge rst_n)
	begin
		if(!rst_n)
		begin
			receive <= 1'b0;
		end
		else
		begin
			if(rxfall && (idle))	// rx falling edge detected while idle, start data receiving process
			begin  
				receive <= 1'b1; 
			end 
			else if(clk_cnt == 8'd175)	// data frame finished
			begin
				receive <= 1'b0;
			end
		end
	end

	always @(posedge baud_clk or negedge rst_n)
	begin
		if(!rst_n)
		begin
			idle <= 1'b1;
			data_out <= 8'd 0;
			parity_bit <= 0;
			clk_cnt <= 8'd0;
			data_rcvd <= 1'b0;
		end
		else
		begin  
			if(receive == 1'b1)		// data receiving process
			begin  
				case (clk_cnt) 
					8'd0:
					begin
						idle <= 1'b0;  
						clk_cnt <= clk_cnt + 8'd1;
						data_rcvd <= 1'b0;
					end
					8'd 8:
					begin
						if(rx==1)	// invalid start bit, exit receiving process
						begin
							idle <= 1;
							clk_cnt <= 8'd 175;
							data_rcvd <= 1'b 0;
						end
						else
						begin
							clk_cnt <= clk_cnt + 8'd 1;
						end
					end
					8'd24:	// receive bit 0
					begin
						idle <= 1'b0;
						data_out[0] <= rx;
						parity_bit <= parity_en^rx;
						clk_cnt <= clk_cnt + 8'd1;
						data_rcvd <= 1'b0;
					end  
					8'd40:	// receive bit 1
					begin
						idle <= 1'b0;
						data_out[1] <= rx;
						parity_bit <= parity_bit^rx;
						clk_cnt <= clk_cnt + 8'd1;
						data_rcvd <= 1'b0;
					end
					8'd56:	// receive bit 2
					begin  
						idle <= 1'b0;
						data_out[2] <= rx;  
						parity_bit <= parity_bit^rx; 
						clk_cnt <= clk_cnt + 8'd1; 
						data_rcvd <= 1'b0;
					end  
					8'd72:	// receive bit 3
					begin  
						idle <= 1'b0;  
						data_out[3] <= rx;  
						parity_bit <= parity_bit^rx; 
						clk_cnt <= clk_cnt + 8'd1; 
						data_rcvd <= 1'b0; 
					end  
					8'd88:	// receive bit 4
					begin  
						idle <= 1'b0;  
						data_out[4] <= rx;  
						parity_bit <= parity_bit^rx; 
						clk_cnt <= clk_cnt + 8'd1; 
						data_rcvd <= 1'b0; 
					end  
					8'd104:	// receive bit 5
					begin  
						idle <= 1'b0;  
						data_out[5] <= rx;  
						parity_bit <= parity_bit^rx; 
						clk_cnt <= clk_cnt + 8'd1; 
						data_rcvd <= 1'b0;
					end  
					8'd120:	// receive bit 6
					begin  
						idle <= 1'b0;
						data_out[6] <= rx;  
						parity_bit <= parity_bit^rx; 
						clk_cnt <= clk_cnt + 8'd1; 
						data_rcvd <= 1'b0; 
					end  
					8'd136:	// receive bit 7
					begin  
						idle <= 1'b0;  
						data_out[7] <= rx;  
						parity_bit <= parity_bit^rx; 
						clk_cnt <= clk_cnt + 8'd1; 
						data_rcvd <= 1'b0; 
					end  
					8'd152:	// receive parity_bit/stop_bit
					begin  
						if(parity_en)	// parity_bit
						begin
							idle <= 1'b0;
							clk_cnt <= clk_cnt + 8'd 1;
							data_rcvd <= 1'b0;

							if(parity_bit == rx)
							begin
								dataerror <= 1'b0;
							end
							else
							begin
								dataerror <= 1'b1;
							end
						end
						else			// stop_bit
						begin
							idle <= 1'b1;
							clk_cnt <= 8'd 175;
							data_rcvd <= 1'b1;

							if(rx == 1)
							begin
								frameerror <= 1'b0;
							end
							else
							begin
								frameerror <= 1'b1;
							end
						end
					end
					8'd168:
					begin  
						idle <= 1'b1;
						if(1'b1 == rx)
						begin
							frameerror <= 1'b0;
						end
						else
						begin
							frameerror <= 1'b1;
						end
						clk_cnt <= 8'd 175;
						data_rcvd <= 1'b1;
					end
					default:
					begin
						clk_cnt <= clk_cnt + 8'd1;
					end
				endcase
			end
			else
			begin
				clk_cnt <= 8'd0;
				idle <= 1'b1;
				data_rcvd <= 1'b0;
			end
		end
	end

endmodule
