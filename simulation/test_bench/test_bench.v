
`timescale 1 ns/100 ps

module test_bench();

	reg sys_clk;		// clk, 40 MHz, period of 25 ns
	reg sys_rst;
	
	wire uart_tx;
	wire uart_rx;

	reg motor_fwd_limit_x;
	reg motor_rvs_limit_x;
	reg motor_home_x;
	wire motor_clk_x;
	wire motor_dir_x;
	reg motor_fwd_limit_y;
	reg motor_rvs_limit_y;
	reg motor_home_y;
	wire motor_clk_y;
	wire motor_dir_y;
	reg motor_fwd_limit_z;
	reg motor_rvs_limit_z;
	reg motor_home_z;
	wire motor_clk_z;
	wire motor_dir_z;
	reg motor_fwd_limit_w;
	reg motor_rvs_limit_w;
	reg motor_home_w;
	wire motor_clk_w;
	wire motor_dir_w;
	
	reg pc_trigger;
	reg [7:0] trigger_cnt;
	reg pc_cs;
	reg pc_rd;
	reg [7:0] pc_data_out;
	wire [7:0] pc_data;
	wire baud_clk;
	wire pc_sent_ok;
	
	assign pc_data = (!pc_cs & !pc_rd)? 8'd z: pc_data_out;

	initial
	begin
		sys_clk = 0;
		sys_rst  = 1;
		
		# 100 sys_rst = 0;
		# 200 sys_rst = 1;
	end
	
	always
	begin
		# 12.5 sys_clk = ~sys_clk;		// clk period of 25 ns
	end
	
	always @ (posedge baud_clk or negedge sys_rst)
	begin
	  if(!sys_rst)
	  begin
	    pc_trigger <= 0;
	    trigger_cnt <= 8'd 0;
	  end
	  else
	  begin
      if(trigger_cnt <=8'd 200)
      begin
        trigger_cnt <= trigger_cnt + 8'd 1;
      end
	    if(trigger_cnt == 8'd 5)
	    begin
	      pc_trigger <= 1;
	    end
	    else
	    begin
	      pc_trigger <= 0;
	    end
	  end
	end
	
	always @ (posedge baud_clk or negedge sys_rst)
	begin
	  if(!sys_rst)
	  begin
	    pc_data_out <= 8'h 00;
	    pc_cs <= 1;
	    pc_rd <= 1;
	  end
	  else
	  begin
	    if(pc_trigger || pc_sent_ok)
	    begin
	      pc_cs <= 0;
	      case(pc_data_out)
	        8'h 00:
	        begin
	          pc_data_out <= 8'h 55;
	        end
	        8'h 55:
	        begin
	          pc_data_out <= 8'h 31;
	        end
	        8'h 31:
	        begin
	          pc_data_out <= 8'h 01;
	        end
	        8'h 01:
	        begin
	          pc_data_out <= 8'h 64;
	        end
	        8'h 64:
	        begin
	          pc_data_out <= 8'h 11;
	        end
	        8'h 11:
	        begin
	          pc_data_out <= 8'h 12;
	        end
	        8'h 12:
	        begin
	          pc_data_out <= 8'h 13;
	        end
	        8'h 13:
	        begin
	          pc_data_out <= 8'h 14;
	        end
	        8'h 14:
	        begin
	          pc_data_out <= 8'h aa;
	        end
	        default:
	        begin
	          pc_data_out <= 8'h 55;
	        end
	      endcase
	    end
	    else
	    begin
	      pc_cs <= 1;
	    end
	  end
  end
	

  defparam pc_inst.CLK_FREQ = 32'd 40_000_000;
	uart_transceiver pc_inst(
		.clk(sys_clk),
		.rst(sys_rst),
		
		.rx(uart_tx),
		.tx(uart_rx),
		
		.cs_n(pc_cs),
		.rd_n(pc_rd),
		.data(pc_data),
		.got_data(),
		.tx_idle(),
		.tx_ok(pc_sent_ok),
		.baud_clk(baud_clk)
	);
	

  motion_controller controller_inst(
		.clk_in(sys_clk),
		.rst_in(sys_rst),
		.rst_in2(1),
		
		.sys_error(),
		
		.uart_tx(uart_tx),
		.uart_rx(uart_rx),
		
		.motor_fwd_limit_x(),
		.motor_rvs_limit_x(),
		.motor_home_x(),
		.motor_clk_x(),
		.motor_dir_x(),
		.motor_fwd_limit_y(),
		.motor_rvs_limit_y(),
		.motor_home_y(),
		.motor_clk_y(),
		.motor_dir_y(),
		.motor_fwd_limit_z(),
		.motor_rvs_limit_z(),
		.motor_home_z(),
		.motor_clk_z(),
		.motor_dir_z(),
		.motor_fwd_limit_w(),
		.motor_rvs_limit_w(),
		.motor_home_w(),
		.motor_clk_w(),
		.motor_dir_w(),
		
		.led1(),
		.led2(),
		.led3(),
		.led4()
	);

endmodule
