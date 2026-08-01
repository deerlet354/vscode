module uart_top(
	input wire sysclk_i,
	output wire uart_tx_o //o:output uart tx发送
);

parameter PARAM_CLK = 32'd100000000;	   //100MHZ
parameter T1MS_CNT = PARAM_CLK / 1000 - 1; //1ms计数最大周期数
parameter DELAY_MAX = 4'd5;				   //延时最大计数次数

parameter S_START 	 = 2'd0;//开始
parameter S_BUSY	 = 2'd1;//忙状态等待
parameter S_BYTE_END = 2'd2;//发送一个字节结束
parameter S_DELAY 	 = 2'd3;//延迟

//关于延时的变量
wire t1ms_done;
wire delay_end;
reg [19:0] t1ms_cnt = 20'd0;			   		 //1ms计数器
reg [3:0] delay_cnt = 4'd0;				  		 //延时计数器
assign t1ms_done = (t1ms_cnt == T1MS_CNT); 		 //1ms计数结束
assign delay_end = ((delay_cnt == DELAY_MAX - 1) && (t1ms_done == 1'b1)); //1ms计数结束

reg [0:7] ddd = 1'b0;
//关于复位信号的变量
reg [15:0] rst_cnt = 16'd0;		//复位信号计数器
wire uart_rstn_i;				//复位信号
//关于待发送数据的变量
reg [7:0] uart_tx_buf[0:11];	//发送缓存
reg [3:0] tx_index = 4'd0;		//发送index计数器
reg [7:0] uart_wdata;			//发送一个字节数据
//关于发送状态的变量
reg uart_wreq;					//UART发送请求
reg [1:0] S_UART_TX;			//UART 发送状态机
wire uart_busy;					//发送模块忙(1),空闲(0)

assign uart_rstn_i = (rst_cnt[15] == 1'b1);//延时后发送复位释放信号

always @(posedge sysclk_i) begin
	rst_cnt <= (rst_cnt[15] == 1'b0) ? (rst_cnt + 1'b1) : rst_cnt;//延时327.68us
end

always @(posedge sysclk_i) begin
	if(uart_rstn_i == 1'b0) begin
		t1ms_cnt <= 20'd0;
	end
	else if(S_UART_TX == S_DELAY) begin
		if(t1ms_cnt == T1MS_CNT) begin
			t1ms_cnt <= 20'd0;
		end
		else begin
			t1ms_cnt <= t1ms_cnt + 1'b1;
		end
	end
end

always @(posedge sysclk_i) begin
	if(uart_rstn_i == 1'b0) begin
		delay_cnt <= 4'd0;
	end
	else if((S_UART_TX == S_DELAY) && (t1ms_done == 1'b1)) begin
		if(delay_cnt < DELAY_MAX - 1) begin
			delay_cnt <= delay_cnt + 4'd1;
		end
		else if(delay_cnt == DELAY_MAX - 1) begin
			delay_cnt <= 4'd0;
		end
	end
end

always @(posedge sysclk_i) begin
	if(uart_rstn_i == 1'b0)begin
		uart_tx_buf[0] <= 8'h48;	//h
		uart_tx_buf[1] <= 8'h45;	//e
		uart_tx_buf[2] <= 8'h4c;	//l
		uart_tx_buf[3] <= 8'h4c;	//l
		uart_tx_buf[4] <= 8'h4f;	//o
		uart_tx_buf[5] <= 8'h20;	//space
		uart_tx_buf[6] <= 8'h46;	//f
		uart_tx_buf[7] <= 8'h50;	//p
		uart_tx_buf[8] <= 8'h47;	//g
		uart_tx_buf[9] <= 8'h41;	//a
		uart_tx_buf[10] <= 8'h0d;	//enter
		uart_tx_buf[11] <= 8'h0a;	//newline

		uart_wreq <= 1'b0;
		uart_wdata <= 8'd0;
		S_UART_TX <= S_START;
		tx_index <= 4'd0;
	end
	else begin
		case(S_UART_TX) 
			S_START: begin
				if(uart_busy == 1'b0) begin
					uart_wdata <= uart_tx_buf[tx_index];
					uart_wreq <= 1'b1;
				end
				else begin
					uart_wreq <= 1'b0;
					S_UART_TX <= S_BUSY;
				end
			end
			S_BUSY: begin
				if(uart_busy == 1'b0) begin
					S_UART_TX <= S_BYTE_END;
				end
				else begin
					S_UART_TX <= S_UART_TX;
				end
			end
			S_BYTE_END: begin
				if(tx_index < 11) begin
					tx_index <= tx_index + 1'b1;
					S_UART_TX <= S_START;
				end
				else begin
					S_UART_TX <= S_DELAY;
				end
			end
			S_DELAY: begin
				if(delay_end == 1'b1) begin
					uart_wreq <= 1'b0;
					uart_wdata <= 8'd0;
					S_UART_TX <= S_START;
					tx_index <= 4'd0;
					t1ms_cnt <= 20'd0; //清零1ms计数器
					delay_cnt <= 4'd0; //清零延时计数器
				end
			end
		endcase
	end
end

uart_tx#
(
	.BAUD_DIV(PARAM_CLK / 115200 - 1) //波特率计算 BAUD_DIV = 系统时钟 / 波特率 - 1
)
uart_tx_inst
(
	.clk_i(sysclk_i), 			//系统时钟输入
	.uart_rstn_i(uart_rstn_i),	//系统复位输入
	.uart_wreq_i(uart_wreq),	//UART发送(写)数据请求
	.uart_wdata_i(uart_wdata),	//UART发送(写)数据
	.uart_busy_o(uart_busy),	//UART发送驱动器忙
	.uart_tx_o(uart_tx_o)		//UART 发送串行总线
);

endmodule
