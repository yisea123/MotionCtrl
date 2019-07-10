/*
  reg_addr:
  		1: pulse_speed_limitL, read/write; motor pulses/sec
  		2: pulse_top_speed, read/write; motor pulses/sec
  		3: pulse_acc_val, read/write; motor pulses/sec/100 us
		4: pulse_dcc_val, read/write; motor pulses/sec/100 us
		5: dcc_position1, write only; pulses
		6: write target_position1 or read current position; pulses
		7: dcc_position2, write only; pulses
  		8: target_position2, write only; pulses
		9: repeat counts, read/write;
		10: motor_enable;
  		11: motor_start;
		12: motor_home;
  		
  rdwr: low is to write, high is to read;
  cs: low valid;
*/

module motor_control(
		clk_40MHz,
		clk_10kHz,
		rst,
		reg_addr,
		data_bus,
		rdwr,
		cs,
		oe,
		
		m_clk,
		m_dir,
		m_enable,
		m_home,
		m_fwd_limit,
		m_bwd_limit,
		
		m_at_home,
		m_at_fwd_limit,
		m_at_bwd_limit,
		m_busy
	);/*synthesis noprune*/

	input clk_40MHz;
	input clk_10kHz;
	input rst;
	input [7:0] reg_addr;
	inout signed [31:0] data_bus;
	input rdwr;
	input cs;
	input oe;
	
	output reg m_clk;
	output reg m_dir;
	output reg m_enable;
	input m_home;
	input m_fwd_limit;
	input m_bwd_limit;
	
	output reg m_at_home;
	output reg m_at_fwd_limit;
	output reg m_at_bwd_limit;
	output reg m_busy;
	
	reg m_once_at_home;
	
	reg signed [31:0] data_bus_store;
	assign data_bus = (!cs&!oe)? data_bus_store:32'b z;
	
	/* motion control registers */
	reg [31:0] pulse_speed_limitL;
	reg [31:0] pulse_top_speed;
	reg [31:0] pulse_acc_val;
	reg [31:0] pulse_dcc_val;
	reg signed [31:0] dcc_position_left;
	reg signed [31:0] target_position_left;
	reg signed [31:0] dcc_position_right;
	reg signed [31:0] target_position_right;
	reg signed [31:0] crnt_position;
	reg signed [31:0] dcc_position;
	reg signed [31:0] target_position;
	reg [31:0] mtn_repeats;
	reg [31:0] crnt_repeat;
	reg motion_start;
	reg motion_stop;
	reg home_start;
	
	/* motor control register addresses defination */
	parameter ADDR_FREQ_LIMITL=8'd 1;
	parameter ADDR_PULSE_SPEED=8'd 2;
	parameter ADDR_ACC_VAL=8'd 3;
	parameter ADDR_DCC_VAL=8'd 4;
	parameter ADDR_DCC_POS_L=8'd 5;
	parameter ADDR_TGT_POS_L=8'd 6;
	parameter ADDR_DCC_POS_R=8'd 7;
	parameter ADDR_TGT_POS_R=8'd 8;
	parameter ADDR_MTN_REPEAT=8'd 9;
	parameter ADDR_MTR_EN=8'd 10;
	parameter ADDR_START_MTN=8'd 11;
	parameter ADDR_HOME=8'd 12;
	parameter ADDR_STATE=8'd 13;
	
	parameter MOTION_DIR_FWD=1'b 0;
	parameter MOTION_DIR_BWD=1'b 1;
	
	/* Visit registers & status logic */
	always @ (posedge clk_40MHz or negedge rst)
	begin
		if(!rst)
		begin
			pulse_speed_limitL <= 32'd 0;
			pulse_top_speed <= 32'd 0;
			pulse_acc_val <= 32'd 0;
			pulse_dcc_val <= 32'd 0;
			dcc_position_left <= 32'd 0;
			target_position_left <= 32'd 0;
			dcc_position_right <= 32'd 0;
			target_position_right <= 32'd 0;
			mtn_repeats <= 32'd 0;
			motion_start <= 0;
			motion_stop <= 0;
			m_enable <= 0;
			home_start <= 0;
		end
		else
		begin
			if(cs==0)
			begin
				if(rdwr==0)	// write
				begin
					case (reg_addr)
						ADDR_FREQ_LIMITL:
						begin
							pulse_speed_limitL <= data_bus;
						end
						ADDR_PULSE_SPEED:
						begin
							pulse_top_speed <= data_bus;
						end
						ADDR_ACC_VAL:
						begin
							pulse_acc_val <= data_bus;
							if(pulse_dcc_val == 32'd 0)
							begin
								pulse_dcc_val <= data_bus;
							end
						end
						ADDR_DCC_VAL:
						begin
							pulse_dcc_val <= data_bus;
						end
						ADDR_DCC_POS_L:
						begin
							dcc_position_left <= data_bus;
						end
						ADDR_DCC_POS_R:
						begin
							dcc_position_right <= data_bus;
						end
						ADDR_TGT_POS_L:
						begin
							target_position_left <= data_bus;
						end
						ADDR_TGT_POS_R:
						begin
							target_position_right <= data_bus;
						end
						ADDR_MTN_REPEAT:
						begin
							mtn_repeats <= data_bus;
						end
						ADDR_MTR_EN:
						begin
							m_enable <= data_bus[0];
						end
						ADDR_START_MTN:
						begin
							if(data_bus[0]==1)
							begin
								motion_start <= 1;
							end
							else
							begin
								motion_stop <= 1;
							end
						end
						ADDR_HOME:
						begin
							home_start <= data_bus[0];
						end
					endcase
				end
				else	// read
				begin
					case (reg_addr)
						ADDR_TGT_POS_L:
						begin
							data_bus_store <= crnt_position;
						end
						ADDR_MTN_REPEAT:
						begin
							data_bus_store <= crnt_repeat;
						end
						ADDR_STATE:
						begin
							data_bus_store <= {27'd 0, m_at_home, m_at_fwd_limit, m_at_bwd_limit, m_busy, m_enable};
						end
					endcase
				end
			end
			else
			begin
				motion_start <= 0;
				motion_stop <= 0;
				home_start <= 0;
			end
		end
	end
	
	/* Motion status */
	reg m_fwd_limit_d;
	reg m_bwd_limit_d;
	reg m_home_d;
	
	always @ (posedge clk_40MHz or negedge rst)
	begin
		if(!rst)
		begin
			m_fwd_limit_d <= 0;
			m_bwd_limit_d <= 0;
		end
		else
		begin
			m_fwd_limit_d <= m_fwd_limit;
			m_bwd_limit_d <= m_bwd_limit;
		end
	end
	
	always @ (posedge clk_40MHz or negedge rst)
	begin
		if(!rst)
		begin
			m_at_fwd_limit <= 0;
		end
		else
		begin
			if(m_fwd_limit & !m_fwd_limit_d & m_dir==MOTION_DIR_FWD)
			begin
				m_at_fwd_limit <= 1;
			end
			else if(!m_fwd_limit & m_fwd_limit_d & m_dir==MOTION_DIR_BWD)
			begin
				m_at_fwd_limit <= 0;
			end
		end
	end

	always @ (posedge clk_40MHz or negedge rst)
	begin
		if(!rst)
		begin
			m_at_bwd_limit <= 0;
		end
		else
		begin
			if(m_bwd_limit & !m_bwd_limit_d & m_dir==MOTION_DIR_BWD)
			begin
				m_at_bwd_limit <= 1;
			end
			else if(!m_bwd_limit & m_bwd_limit_d & m_dir==MOTION_DIR_FWD)
			begin
				m_at_bwd_limit <= 0;
			end
		end
	end
	
	always @ (posedge clk_40MHz or negedge rst)
	begin
		if(!rst)
		begin
			m_home_d <= 0;
		end
		else
		begin
			m_home_d <= m_home;
		end
	end
	
	always @ (posedge clk_40MHz or negedge rst)
	begin
		if(!rst)
		begin
			m_once_at_home <= 0;
			m_at_home <= 0;
		end
		else
		begin
			case (motion_sta_crnt)
				STA_HOME_BWD:
				begin
					m_once_at_home <= 0;
					m_at_home <= 0;
				end
				STA_HOME_BACK:
				begin
					if(!m_home & m_home_d)
					begin
						m_once_at_home <= 1;
						m_at_home <= 1;
					end
				end
				default:
				begin
					if(m_once_at_home && crnt_position == 32'd 0)
					begin
						m_at_home <= 1;
					end
					else
					begin
						m_at_home <= 0;
					end
				end
			endcase
		end
	end
	
	/* Motion Action state machine */
	parameter STA_IDLE=4'b 0000;
	parameter STA_HOME_BWD=4'b 0001;
	parameter STA_HOME_STOP=4'b 0011;
	parameter STA_HOME_BACK=4'b 0100;
	parameter STA_MOTION_ACC=4'b 0101;
	parameter STA_MOTION_CON=4'b 0110;
	parameter STA_MOTION_DCC=4'b 0111;
	parameter STA_MOTION_BRK=4'b 1000;
	parameter STA_MOTION_STOP=4'b 1001;
	parameter STA_MOTION_HOLD=4'b 1010;
	reg [3:0] motion_sta_crnt;
	reg [3:0] motion_sta_next;
	
	always @ (posedge clk_40MHz or negedge rst)
	begin
		if(!rst)
		begin
			motion_sta_crnt <= STA_IDLE;
		end
		else
		begin
			motion_sta_crnt <= motion_sta_next;
		end
	end
	
	always @ ( * )
	begin
		case (motion_sta_crnt)
			STA_IDLE:
			begin
				if(home_start)
				begin
					motion_sta_next = STA_HOME_BWD;
				end
				else if(motion_start)
				begin
					motion_sta_next = STA_MOTION_ACC;
				end
				else
				begin
					motion_sta_next = STA_IDLE;
				end
			end
			STA_HOME_BWD:
			begin
				if(m_home)
				begin
					motion_sta_next = STA_HOME_STOP;
				end
				else if(m_bwd_limit)
				begin
					motion_sta_next = STA_MOTION_BRK;
				end
				else if(motion_stop)
				begin
					motion_sta_next = STA_MOTION_STOP;
				end
				else
				begin
					motion_sta_next = STA_HOME_BWD;
				end
			end
			STA_HOME_STOP:
			begin
				if(m_bwd_limit)
				begin
					motion_sta_next = STA_MOTION_BRK;
				end
				else if(pulse_speed_crnt <= pulse_speed_limitL)
				begin
					motion_sta_next = STA_HOME_BACK;
				end
				else if(motion_stop)
				begin
					motion_sta_next = STA_MOTION_STOP;
				end
				else
				begin
					motion_sta_next = STA_HOME_STOP;
				end
			end
			STA_HOME_BACK:
			begin
				if(!m_home & m_home_d)
				begin
					motion_sta_next = STA_IDLE;
				end
				else if(m_fwd_limit)
				begin
					motion_sta_next = STA_MOTION_BRK;
				end
				else if(motion_stop)
				begin
					motion_sta_next = STA_MOTION_STOP;
				end
				else
				begin
					motion_sta_next = STA_HOME_BACK;
				end
			end
			STA_MOTION_ACC:
			begin
				if(m_fwd_limit & m_dir == MOTION_DIR_FWD)
				begin
					motion_sta_next = STA_MOTION_BRK;
				end
				else if(m_bwd_limit & m_dir == MOTION_DIR_BWD)
				begin
					motion_sta_next = STA_MOTION_BRK;
				end
				else if(crnt_position == dcc_position)
				begin
					motion_sta_next = STA_MOTION_DCC;
				end
				else if(crnt_position == target_position)
				begin
					motion_sta_next = STA_MOTION_HOLD;
				end
				else if(pulse_speed_crnt >= pulse_top_speed)
				begin
					motion_sta_next = STA_MOTION_CON;
				end
				else if(motion_stop)
				begin
					motion_sta_next = STA_MOTION_STOP;
				end
				else
				begin
					motion_sta_next = STA_MOTION_ACC;
				end
			end
			STA_MOTION_CON:
			begin
				if(m_fwd_limit & m_dir == MOTION_DIR_FWD)
				begin
					motion_sta_next = STA_MOTION_BRK;
				end
				else if(m_bwd_limit & m_dir == MOTION_DIR_BWD)
				begin
					motion_sta_next = STA_MOTION_BRK;
				end
				else if(crnt_position == dcc_position)
				begin
					motion_sta_next = STA_MOTION_DCC;
				end
				else if(crnt_position == target_position)
				begin
					motion_sta_next = STA_MOTION_HOLD;
				end
				else if(motion_stop)
				begin
					motion_sta_next = STA_MOTION_STOP;
				end
				else
				begin
					motion_sta_next = STA_MOTION_CON;
				end
			end
			STA_MOTION_DCC:
			begin
				if(m_fwd_limit & m_dir == MOTION_DIR_FWD)
				begin
					motion_sta_next = STA_MOTION_BRK;
				end
				else if(m_bwd_limit & m_dir == MOTION_DIR_BWD)
				begin
					motion_sta_next = STA_MOTION_BRK;
				end
				else if(crnt_position == target_position)
				begin
					motion_sta_next = STA_MOTION_HOLD;
				end
				else if(motion_stop)
				begin
					motion_sta_next = STA_MOTION_STOP;
				end
				else
				begin
					motion_sta_next = STA_MOTION_DCC;
				end
			end
			STA_MOTION_HOLD:
			begin
				if(crnt_repeat < mtn_repeats)
				begin
					motion_sta_next = STA_MOTION_ACC;
				end
				else
				begin
					motion_sta_next = STA_IDLE;
				end
			end
			default:
			begin
				motion_sta_next = STA_IDLE;
			end
		endcase
	end
	
	/* 100us timer, motion control rate */
	reg clk_10kHz_d;
	
	always @ (posedge clk_40MHz or negedge rst)
	begin
		if(!rst)
		begin
			clk_10kHz_d <= 0;
		end
		else
		begin
			clk_10kHz_d <= clk_10kHz;
		end
	end
	
	/* motion acc/dcc control */
	reg [31:0] pulse_speed_crnt;
	reg [31:0] acc_cnt;
	reg [31:0] m_clk_divider;
	reg [31:0] m_clk_cnt;
	reg [31:0] pulse_speed_crnt_d;
	reg m_clk_d;
	
	always @ (posedge clk_10kHz or negedge rst)
	begin
		if(!rst)
		begin
			acc_cnt <= 32'd 0;
		end
		else
		begin
			case (motion_sta_next)
				STA_HOME_BWD:
				begin
					if(pulse_speed_crnt < pulse_top_speed)
					begin
						acc_cnt <= acc_cnt + 32'd 1;
					end
				end
				STA_HOME_STOP:
				begin
					if(motion_sta_crnt != STA_HOME_STOP)
					begin
						acc_cnt <= 32'd 0;
					end
					else
					begin
						acc_cnt <= acc_cnt + 32'd 1;
					end
				end
				STA_MOTION_ACC:
				begin
					if(motion_sta_crnt != STA_MOTION_ACC)
					begin
						acc_cnt <= 32'd 0;
					end
					else
					begin
						acc_cnt <= acc_cnt + 32'd 1;
					end
				end
				STA_MOTION_DCC:
				begin
					if(motion_sta_crnt != STA_MOTION_DCC)
					begin
						acc_cnt <= 32'd 0;
					end
					else
					begin
						if(pulse_speed_crnt > pulse_speed_limitL)
						begin
							acc_cnt <= acc_cnt + 32'd 1;
						end
					end
				end
				STA_MOTION_BRK:
				begin
					if(motion_sta_crnt != STA_MOTION_BRK)
					begin
						acc_cnt <= 32'd 0;
					end
					else
					begin
						acc_cnt <= acc_cnt + 32'd 1;
					end
				end
				STA_MOTION_STOP:
				begin
					if(motion_sta_crnt != STA_MOTION_STOP)
					begin
						acc_cnt <= 32'd 0;
					end
					else
					begin
						acc_cnt <= acc_cnt + 32'd 1;
					end
				end
				default:
				begin
					acc_cnt <= 32'd 0;
				end
			endcase
		end
	end
	
	always @ (posedge clk_40MHz or negedge rst)
	begin
		if(!rst)
		begin
			pulse_speed_crnt <= 32'd 0;
		end
		else
		begin
			case (motion_sta_next)
				STA_IDLE:
				begin
					pulse_speed_crnt <= 32'd 0;
				end
				STA_HOME_BWD:
				begin
					if(motion_sta_crnt != STA_HOME_BWD)
					begin
						pulse_speed_crnt <= pulse_speed_limitL;
					end
					else
					begin
						if(pulse_speed_crnt >= pulse_top_speed)
						begin
							pulse_speed_crnt <= pulse_top_speed;
						end
						else if(clk_10kHz&!clk_10kHz_d)
						begin
							if(pulse_speed_crnt < pulse_top_speed)
							begin
								pulse_speed_crnt <= pulse_speed_crnt + acc_cnt * pulse_acc_val;
							end
						end
					end
				end
				STA_HOME_STOP:
				begin
					if(clk_10kHz&!clk_10kHz_d)
					begin
						pulse_speed_crnt <= pulse_speed_crnt - acc_cnt * pulse_dcc_val;
					end
				end
				STA_HOME_BACK:
				begin
					pulse_speed_crnt <= 32'd 256;
				end
				STA_MOTION_ACC:
				begin
					if(motion_sta_crnt != STA_MOTION_ACC)
					begin
						pulse_speed_crnt <= pulse_speed_limitL;
					end
					else
					begin
						if(pulse_speed_crnt >= pulse_top_speed)
						begin
							pulse_speed_crnt <= pulse_top_speed;
						end
						else if(clk_10kHz&!clk_10kHz_d)
						begin
							if(pulse_speed_crnt < pulse_top_speed)
							begin
								pulse_speed_crnt <= pulse_speed_crnt + acc_cnt * pulse_acc_val;
							end
						end
					end
				end
				STA_MOTION_CON:
				begin
					pulse_speed_crnt <= pulse_top_speed;
				end
				STA_MOTION_DCC:
				begin
					if(pulse_speed_crnt < pulse_speed_limitL)
					begin
						pulse_speed_crnt <= pulse_speed_limitL;
					end
					else if(clk_10kHz&!clk_10kHz_d)
					begin
						if(pulse_speed_crnt > pulse_speed_limitL)
						begin
							pulse_speed_crnt <= pulse_speed_crnt - acc_cnt * pulse_dcc_val;
						end
					end
				end
				STA_MOTION_BRK:
				begin
					if(pulse_speed_crnt < pulse_speed_limitL)
					begin
						pulse_speed_crnt <= 0;
					end
					else if(clk_10kHz&!clk_10kHz_d)
					begin
						pulse_speed_crnt <= pulse_speed_crnt - acc_cnt * 32'd 100;
					end
				end
				STA_MOTION_STOP:
				begin
					if(pulse_speed_crnt < pulse_speed_limitL)
					begin
						pulse_speed_crnt <= 0;
					end
					else if(clk_10kHz&!clk_10kHz_d)
					begin
						if(pulse_speed_crnt > pulse_speed_limitL)
						begin
							pulse_speed_crnt <= pulse_speed_crnt - acc_cnt * pulse_dcc_val;
						end
					end
				end
			endcase
		end
	end
	
	always @ (posedge clk_40MHz or negedge rst)
	begin
		if(!rst)
		begin
			dcc_position <= 32'd 0;
			target_position <=32'd 0;
			crnt_repeat <= 32'd 0;
		end
		else
		begin
			case (motion_sta_next)
				STA_IDLE:
				begin
					dcc_position <= 32'd 0;
					target_position <= 32'd 0;
					crnt_repeat <= 32'd 0;
				end
				STA_MOTION_ACC:
				begin
					if(motion_sta_crnt == STA_IDLE)
					begin
						dcc_position <= dcc_position_left;
						target_position <= target_position_left;
						crnt_repeat <= 32'd 0;
					end
					else if(motion_sta_crnt == STA_MOTION_HOLD)
					begin
						if(target_position == target_position_left)
						begin
							dcc_position <= dcc_position_right;
							target_position <= target_position_right;
							crnt_repeat <= crnt_repeat + 32'd 1;
						end
						else
						begin
							dcc_position <= dcc_position_left;
							target_position <= target_position_left;
						end
					end
				end
			endcase
		end
	end

	always @ (posedge clk_40MHz or negedge rst)
	begin
		if(!rst)
		begin
			pulse_speed_crnt_d <= 32'd 0;
			m_clk_divider <= 32'd 0;
		end
		else
		begin
			pulse_speed_crnt_d <= pulse_speed_crnt;
			if(pulse_speed_crnt_d!=pulse_speed_crnt)
			begin
				if(pulse_speed_crnt > 32'd 0)
				begin
					m_clk_divider <= 32'd 20_000_000 / pulse_speed_crnt;
				end
				else
				begin
					m_clk_divider <= 32'd 0;
				end
			end
		end
	end
	
	always @ (posedge clk_40MHz or negedge rst)
	begin
		if(!rst)
		begin
			m_clk_cnt <= 32'd 0;
			m_clk <= 0;
		end
		else
		begin
			case (motion_sta_next)
				STA_IDLE:
				begin
					m_clk_cnt <= 32'd 0;
					m_clk <= 0;
				end
				default:
				begin
					if(m_clk_divider == 32'd 0)
					begin
						m_clk_cnt <= 32'd 0;
						m_clk <= 0;
					end
					else if(m_clk_cnt >= m_clk_divider -1)
					begin
						m_clk_cnt <= 32'd 0;
						m_clk = ~m_clk;
					end
					else
					begin
						m_clk_cnt <= m_clk_cnt + 32'd 1;
					end
				end
			endcase
		end
	end
	
	always @ (posedge clk_40MHz or negedge rst)
	begin
		if(!rst)
		begin
			m_clk_d <= 0;
		end
		else
		begin
			m_clk_d <= m_clk;
		end
	end
	
	always @ (posedge clk_40MHz or negedge rst)
	begin
		if(!rst)
		begin
			m_dir <= 0;
		end
		else
		begin
			case (motion_sta_next)
				STA_IDLE:
				begin
					m_dir <= 0;
				end
				STA_HOME_BWD:
				begin
					m_dir <= MOTION_DIR_BWD;
				end
				STA_HOME_STOP:
				begin
					m_dir <= MOTION_DIR_BWD;
				end
				STA_HOME_BACK:
				begin
					m_dir <= MOTION_DIR_FWD;
				end
				STA_MOTION_BRK:
				begin
					m_dir <= m_dir;
				end
				default:
				begin
					if(target_position > crnt_position)
					begin
						m_dir <= MOTION_DIR_FWD;
					end
					else
					begin
						m_dir <= MOTION_DIR_BWD;
					end
				end
			endcase
		end
	end
	
	always @ (posedge clk_40MHz or negedge rst)
	begin
		if(!rst)
		begin
			crnt_position <= 32'd 0;
		end
		else
		begin
			case (motion_sta_crnt)
				STA_HOME_BACK:
				begin
					if(!m_home & m_home_d)
					begin
						crnt_position <= 32'd 0;
					end
				end
				default:
				begin
					if(m_enable & m_clk & ! m_clk_d)
					begin
						if(m_dir == MOTION_DIR_FWD)
						begin
							crnt_position <= crnt_position + 32'd 1;
						end
						else
						begin
							crnt_position <= crnt_position - 32'd 1;
						end
					end
				end
			endcase
		end
	end
	
	always @ (posedge clk_40MHz or negedge rst)
	begin
		if(!rst)
		begin
			m_busy <= 0;
		end
		else
		begin
			case (motion_sta_crnt)
				STA_IDLE:
				begin
					m_busy <= 0;
				end
				default:
				begin
					m_busy <= 1;
				end
			endcase
		end
	end

endmodule
