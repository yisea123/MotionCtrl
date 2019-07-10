
module uart_transceiver(
		clk,
		rst,
		
		rx,
		tx,
		
		cs_n,
		rd_n,
		data,
		got_data,
		tx_idle,
		tx_ok,
		baud_clk
	);
	input clk;
	input rst;
	input rx;
	output tx;
	input cs_n;
	input rd_n;
	inout [7:0] data;
	output got_data;
	output tx_idle;
	output tx_ok;
	output baud_clk;
	
	wire [7:0] data_out;
	assign data = (!cs_n & !rd_n) ? data_out : 8'd z;
	
	parameter CLK_FREQ = 32'd 50_000_000;
	parameter BAUDRATE = 115200;
	
	//====== baud rate generation ======//
	defparam baud_inst.CLK_FREQ = CLK_FREQ;
	defparam baud_inst.BAUDRATE = BAUDRATE;
	uart_baud baud_inst(
		.clk(clk),
		.rst_n(rst),
		.baud_clk(baud_clk)		// 16 x baudrate
	);
	
	//====== data receiving ======//
	uart_rx rx_inst(
		.rst_n(rst),
		.baud_clk(baud_clk),
		.rx(rx),
		.parity_en(0),
		.data_out(data_out),
		.data_rcvd(got_data),
		.dataerror(),
		.frameerror()
	);
	
	
	//====== data sending ======//
	uart_tx tx_inst(
		.rst_n(rst),
		.baud_clk(baud_clk),
		.parity_en(0),
		.write(!cs_n & rd_n),
		.datain(data),
		.tx(tx),
		.idle(tx_idle),
		.tx_finish(tx_ok)
	);
	
endmodule
