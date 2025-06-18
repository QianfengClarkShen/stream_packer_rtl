`timescale 1ps/1ps
module banyan # (
    parameter int N = 4,
    parameter int DWIDTH = 8,
    parameter int LOGN = $clog2(N)
) (
    input logic clk,
    input logic [N-1:0][DWIDTH-1:0] din,
    input logic [N-1:0][LOGN-1:0] dst_in,
    input logic [N-1:0]in_vld,
    output logic [N-1:0][DWIDTH-1:0] dout,
    output logic [N-1:0] out_vld
);
    logic [LOGN-2:0][N-1:0][DWIDTH-1:0] int_data;
    logic [LOGN-2:0][N-1:0][LOGN-1:0] int_dst;
    logic [LOGN-2:0][N-1:0] int_vld;

    genvar i,j;

    //input
    //register the first layer
    for (i = 0; i < N/2; i++) begin
        sw2 #(
            .DWIDTH (DWIDTH),
            .AWIDTH (LOGN),
            .REGISTER (1)
        ) input_sw(
            .*,
            .din0     (din[2*i]),
            .dst_in0  (dst_in[2*i]),
            .in_vld0  (in_vld[2*i]),
            .din1     (din[2*i+1]),
            .dst_in1  (dst_in[2*i+1]),
            .in_vld1  (in_vld[2*i+1]),
            .dout0    (int_data[0][i]),
            .dst_out0 (int_dst[0][i]),
            .out_vld0 (int_vld[0][i]),
            .dout1    (int_data[0][i+N/2]),
            .dst_out1 (int_dst[0][i+N/2]),
            .out_vld1 (int_vld[0][i+N/2])
        );
    end

    //core network
    //register every other layer
    for (i = 0; i < LOGN-2; i = i+1) begin
        for (j = 0; j < N/2; j = j+1) begin
            sw2 #(
                .DWIDTH (DWIDTH),
                .AWIDTH (LOGN),
                .REGISTER (i[0])
            ) u_sw2(
                .*,
                .din0     (int_data[i][2*j]),
                .dst_in0  (int_dst[i][2*j]),
                .in_vld0  (int_vld[i][2*j]),
                .din1     (int_data[i][2*j+1]),
                .dst_in1  (int_dst[i][2*j+1]),
                .in_vld1  (int_vld[i][2*j+1]),
                .dout0    (int_data[i+1][j]),
                .dst_out0 (int_dst[i+1][j]),
                .out_vld0 (int_vld[i+1][j]),
                .dout1    (int_data[i+1][j+N/2]),
                .dst_out1 (int_dst[i+1][j+N/2]),
                .out_vld1 (int_vld[i+1][j+N/2])
            );
        end
    end

    //output
    for (i = 0; i < N/2; i++) begin
        sw2 #(
            .DWIDTH (DWIDTH),
            .AWIDTH (LOGN),
            .REGISTER (0)
        ) output_sw(
            .*,
            .din0     (int_data[LOGN-2][2*i]),
            .dst_in0  (int_dst[LOGN-2][2*i]),
            .in_vld0  (int_vld[LOGN-2][2*i]),
            .din1     (int_data[LOGN-2][2*i+1]),
            .dst_in1  (int_dst[LOGN-2][2*i+1]),
            .in_vld1  (int_vld[LOGN-2][2*i+1]),
            .dout0    (dout[i]),
            .dst_out0 (),
            .out_vld0 (out_vld[i]),
            .dout1    (dout[i+N/2]),
            .dst_out1 (),
            .out_vld1 (out_vld[i+N/2])
        );
    end
endmodule