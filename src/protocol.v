
module protocol(
		clk,
		rst,
		baud_clk,
		
		uart_cs,
		uart_rd,
		uart_data,
		uart_got_data,
		uart_tx_finish,
		
		motor_cs_x,
		motor_rd_x,
		motor_oe_x,
		motor_cs_y,
		motor_rd_y,
		motor_oe_y,
		motor_cs_z,
		motor_rd_z,
		motor_oe_z,
		motor_cs_w,
		motor_rd_w,
		motor_oe_w,
		motor_addr,
		motor_data,
		motor_enabled_x,
		motor_home_x,
		motor_fwd_limit_x,
		motor_bwd_limit_x,
		motor_busy_x,
		motor_enabled_y,
		motor_home_y,
		motor_fwd_limit_y,
		motor_bwd_limit_y,
		motor_busy_y,
		motor_enabled_z,
		motor_home_z,
		motor_fwd_limit_z,
		motor_bwd_limit_z,
		motor_busy_z,
		motor_enabled_w,
		motor_home_w,
		motor_fwd_limit_w,
		motor_bwd_limit_w,
		motor_busy_w
		);
	input clk;
	input rst;
	input baud_clk;
	
	output reg uart_cs;
	output reg uart_rd;
	inout [7:0] uart_data;
	input uart_got_data;
	input uart_tx_finish;

	output reg motor_cs_x;
	output reg motor_rd_x;
	output reg motor_oe_x;
	output reg motor_cs_y;
	output reg motor_rd_y;
	output reg motor_oe_y;
	output reg motor_cs_z;
	output reg motor_rd_z;
	output reg motor_oe_z;
	output reg motor_cs_w;
	output reg motor_rd_w;
	output reg motor_oe_w;
	output reg [7:0] motor_addr;
	inout [31:0] motor_data;
	input motor_enabled_x;
	input motor_home_x;
	input motor_fwd_limit_x;
	input motor_bwd_limit_x;
	input motor_busy_x;
	input motor_enabled_y;
	input motor_home_y;
	input motor_fwd_limit_y;
	input motor_bwd_limit_y;
	input motor_busy_y;
	input motor_enabled_z;
	input motor_home_z;
	input motor_fwd_limit_z;
	input motor_bwd_limit_z;
	input motor_busy_z;
	input motor_enabled_w;
	input motor_home_w;
	input motor_fwd_limit_w;
	input motor_bwd_limit_w;
	input motor_busy_w;
	reg [31:0] motor_data_out;
	
	wire motor_cs, motor_oe;
	assign motor_cs = (motor_cs_x & motor_cs_y & motor_cs_z & motor_cs_w);
	assign motor_oe = (motor_oe_x & motor_oe_y & motor_oe_z & motor_oe_w);
	
	assign motor_data = (!motor_cs & !motor_oe) ? 32'd z : motor_data_out;
	
	parameter STA_MONITOR=8'b 0000_0001;
	parameter STA_READ_UART=8'b 0000_0010;
	parameter STA_DECODE_CMD=8'b 0010_0000;
	parameter STA_SEND_MOTOR=8'b 0000_0100;
	parameter STA_READ_MOTOR=8'b 0000_1000;
	parameter STA_SEND_UART=8'b 0001_0000;
	
	reg [63:0] cmd_buf, cmd_buf_store;
	reg [63:0] response;
	reg [3:0] response_ptr;
	
	reg baud_clk_d;
	reg [7:0] uart_tx_data;
	
	reg is_read_cmd;
	reg is_write_cmd;
	reg read_motor_finished;
	reg send_motor_finished;
	reg send_uart_finished;
	reg send_next_byte;
	
	assign uart_data = (!uart_cs & uart_rd)? uart_tx_data:8'd z;

	reg [7:0] sta_next, sta_crnt;
	
	always @ (posedge baud_clk or negedge rst)
	begin
	  if(!rst)
	  begin
	    cmd_buf <= 64'd 0;
	  end
	  else
	  begin
	    if(!uart_cs & !uart_rd)
	    begin
	      cmd_buf <= {cmd_buf[55:0], uart_data};
	    end
	  end
	end
	
	//====== state machine ======//
	always @ (posedge clk or negedge rst)
	begin
		if(!rst)
		begin
			sta_crnt <= STA_MONITOR;
		end
		else
		begin
			sta_crnt <= sta_next;
		end
	end
	
	always @ ( * )
	begin
		case (sta_crnt)
			STA_MONITOR:
			begin
				if(uart_got_data)
				begin
					sta_next = STA_READ_UART;
				end
				else
				begin
					sta_next = STA_MONITOR;
				end
			end
			STA_READ_UART:
			begin
				sta_next = STA_DECODE_CMD;
			end
			STA_DECODE_CMD:
			begin
				if(is_read_cmd)
				begin
					sta_next = STA_READ_MOTOR;
				end
				else if(is_write_cmd)
				begin
					sta_next = STA_SEND_MOTOR;
				end
				else
				begin
					sta_next = STA_MONITOR;
				end
			end
			STA_READ_MOTOR:
			begin
				if(read_motor_finished)
				begin
					sta_next = STA_SEND_UART;
				end
				else
				begin
					sta_next = STA_READ_MOTOR;
				end
			end
			STA_SEND_MOTOR:
			begin
				if(send_motor_finished)
				begin
					sta_next = STA_SEND_UART;
				end
				else
				begin
					sta_next = STA_SEND_MOTOR;
				end
			end
			STA_SEND_UART:
			begin
				if(send_uart_finished)
				begin
					sta_next = STA_MONITOR;
				end
				else
				begin
					sta_next = STA_SEND_UART;
				end
			end
		endcase
	end
	
	//====== uart interface ======//
	always @ (posedge clk or negedge rst)
	begin
		if(!rst)
		begin
			uart_cs <= 1;
			uart_rd <= 1;
			uart_tx_data <= 8'd 0;
		end
		else
		begin
			case (sta_next)
				STA_READ_UART:
				begin
					uart_cs <= 0;
					uart_rd <= 0;
					uart_tx_data <= 8'd 0;
				end
				STA_SEND_UART:
				begin
					if(send_next_byte)
					begin
						uart_cs <= 0;
						uart_rd <= 1;
						case (response_ptr)
							4'd 0:
							begin
								uart_tx_data <= response[63:56];
							end
							4'd 1:
							begin
								uart_tx_data <= response[55:48];
							end
							4'd 2:
							begin
								uart_tx_data <= response[47:40];
							end
							4'd 3:
							begin
								uart_tx_data <= response[39:32];
							end
							4'd 4:
							begin
								uart_tx_data <= response[31:24];
							end
							4'd 5:
							begin
								uart_tx_data <= response[23:16];
							end
							4'd 6:
							begin
								uart_tx_data <= response[15:8];
							end
							4'd 7:
							begin
								uart_tx_data <= response[7:0];
							end
						endcase
					end
				end
				default:
				begin
					uart_cs <= 1;
					uart_rd <= 1;
				end
			endcase
		end
	end
	
	always @ (posedge clk or negedge rst)
	begin
		if(!rst)
		begin
			is_read_cmd <= 0;
			is_write_cmd <= 0;
			
			motor_addr <= 8'd 0;
			motor_data_out <= 32'd 0;
		end
		else
		begin
			case (sta_next)
				STA_DECODE_CMD:
				begin
					if(cmd_buf[63:48] == 16'h 5531 && cmd_buf[7:0] == 8'h aa)
					begin
						motor_data_out <= cmd_buf[39:8];
						case (cmd_buf[47:40])
							8'h 01:			// start speed
								motor_addr <= 1;
						endcase
						
						if(cmd_buf[47:40] == 8'h 01)			// read command
						begin
							is_read_cmd <= 1;
							is_write_cmd <= 0;
						end
						else if(cmd_buf[47:40] == 8'h 02)	// write command
						begin
							is_read_cmd <= 0;
							is_write_cmd <= 1;
						end
						else
						begin
							is_read_cmd <= 0;
							is_write_cmd <= 0;
						end
					end
					else
					begin
						is_read_cmd <= 0;
						is_write_cmd <= 0;
					end
				end
				default:
				begin
					is_read_cmd <= 0;
					is_write_cmd <= 0;
				end
			endcase
		end
	end
	
	always @ (posedge clk or negedge rst)
	begin
		if(!rst)
		begin
			read_motor_finished <= 0;
			send_motor_finished <= 0;
			
			motor_cs_x <= 1;
			motor_rd_x <= 1;
			motor_oe_x <= 1;
			motor_cs_y <= 1;
			motor_rd_y <= 1;
			motor_oe_y <= 1;
			motor_cs_z <= 1;
			motor_rd_z <= 1;
			motor_oe_z <= 1;
			motor_cs_w <= 1;
			motor_rd_w <= 1;
			motor_oe_w <= 1;
		end
		else
		begin
			case (sta_crnt)
				STA_READ_MOTOR:
				begin
					
				end
			endcase
		end
	end

endmodule
