module uart_tx#
(
	parameter integer BAUD_DIV = 10416 //波特率9600
)
(
	input wire clk_i, 				//系统时钟输入
	input wire uart_rstn_i,			//系统复位输入
	input wire uart_wreq_i,			//发送请求
	input wire [7:0] uart_wdata_i,	//发送数据
	output wire uart_busy_o,		//发送状态忙,代表正在发送数据
	output wire uart_tx_o			//发送串行总线
);

localparam UART_LEN = 4'd10;

reg uart_wreq_r = 1'b0; //备份uart_wreq_i前一周期状态，检测边沿，用于判断请求信号

reg bps_start_en = 1'b0; 		 //开始发送
reg [19:0] baud_div = 12'd0;	 //bps计数器
reg [3:0] tx_cnt = 4'd0;		 //bit位计数器 1位起始位+8位数据位+1位停止位 0-9
reg [9:0] uart_wdata_r = 10'h3ff;//发送数据缓存

wire bps_en;
assign uart_busy_o = bps_start_en;		//发送时是忙
assign bps_en = (baud_div == BAUD_DIV);	//计数到才允许发送下一位bit
assign uart_tx_o = uart_wdata_r[0];		//低位先出

always @(posedge clk_i) begin
	uart_wreq_r <= uart_wreq_i;//边沿检测
end

always @(posedge clk_i) begin
	if((uart_rstn_i == 1'b0) || (uart_wreq_i == 1'b1 && uart_wreq_r == 1'b0) 
		|| (tx_cnt == UART_LEN)) begin
		tx_cnt <= 4'd0;
	end
	else if((bps_en == 1'b1) && (tx_cnt < UART_LEN)) begin
		tx_cnt <= tx_cnt + 1'b1;
	end
end

always @(posedge clk_i) begin
	if(uart_rstn_i == 1'b0) begin
		bps_start_en <= 1'b0;
	end
	else if(uart_wreq_i == 1'b1 && uart_wreq_r == 1'b0) begin//检测到上升沿
		bps_start_en <= 1'b1;
	end
	else if(tx_cnt == UART_LEN) begin
		bps_start_en <= 1'b0;
	end
	else begin
		bps_start_en <= bps_start_en;//保持当前状态
	end
end

always @(posedge clk_i) begin
	if((uart_rstn_i == 1'b0) || (uart_wreq_i == 1'b1 && uart_wreq_r == 1'b0)) begin
		baud_div <= 12'd0;
	end
	else if((bps_start_en == 1'b1) && (baud_div < BAUD_DIV)) begin
		baud_div <= baud_div + 1'b1;
	end
	else begin
		baud_div <= 12'd0;
	end
end

always @(posedge clk_i) begin
	if(uart_wreq_i == 1'b1 && uart_wreq_r == 1'b0) begin
		uart_wdata_r <= {1'b1,uart_wdata_i[7:0],1'b0};
	end
	else if((bps_en == 1'b1) && (tx_cnt < (UART_LEN - 1))) begin
		uart_wdata_r <= {uart_wdata_r[0],uart_wdata_r[9:1]};//右移，高位补低位
	end
	else begin
		uart_wdata_r <= uart_wdata_r;
	end
end

endmodule 
