`timescale 1ns / 1ns

module tb_top_uart_tx();

reg sysclk_i;
wire uart_rx;

initial begin
	sysclk_i = 1'b0;
end

always #5 sysclk_i = ~sysclk_i;

uart_top
uart_top_inst
(
	.sysclk_i(sysclk_i),
	.uart_tx_o(uart_rx)
);

endmodule
