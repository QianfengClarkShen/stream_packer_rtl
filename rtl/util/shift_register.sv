`timescale 1ps/1ps

module shift_register #(
    parameter int DWIDTH = 1,
    parameter int DEPTH = 1
) (
    input logic clk,
    input logic [DWIDTH-1:0] din,
    output logic [DWIDTH-1:0] dout
);
    logic [DEPTH-1:0][DWIDTH-1:0] shift_reg;
    always_ff @(posedge clk) begin
        shift_reg[0] <= din;
        for (int i = 1; i < DEPTH; i++)
            shift_reg[i] <= shift_reg[i-1];
    end
    assign dout = shift_reg[DEPTH-1];
endmodule