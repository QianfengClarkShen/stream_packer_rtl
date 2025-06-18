`timescale 1ps/1ps

`ifndef BYTES_IN
`define BYTES_IN 4
`endif
`ifndef BYTES_OUT
`define BYTES_OUT 4
`endif

module stream_packer #(
/*
Parameters for Stream Packer Module
N_BYTES_IN: Number of bytes in the input sparse stream
N_BYTES_OUT: Number of bytes in the output packed stream
*/
    parameter int N_BYTES_IN = `BYTES_IN,
    parameter int N_BYTES_OUT = `BYTES_OUT
) (
/*
Port declarations for the Stream Packer Module
clk: Clock signal
rst: Reset signal
sparse_t****: Input sparse AXI Stream signals
packed_t****: Output packed AXI Stream signals
*/
    input logic clk,
    input logic rst,
    input logic [N_BYTES_IN*8-1:0] sparse_tdata,
    input logic [N_BYTES_IN-1:0] sparse_tkeep,
    input logic sparse_tlast,
    input logic sparse_tvalid,
    output logic sparse_tready,
    output logic [N_BYTES_OUT*8-1:0] packed_tdata,
    output logic [N_BYTES_OUT-1:0] packed_tkeep,
    output logic packed_tlast,
    output logic packed_tvalid,
    input logic packed_tready
);
    localparam int DWIDTH_IN = N_BYTES_IN * 8;
    localparam int DWIDTH_OUT = N_BYTES_OUT * 8;
    localparam int C_IN = $clog2(N_BYTES_IN+1);
    localparam int N = 2**$clog2(N_BYTES_OUT+N_BYTES_IN);
    localparam int LOGN = $clog2(N);

    logic [N_BYTES_IN-1:0][7:0] in_data;
    logic [N_BYTES_IN-1:0][C_IN-1:0] in_bytes;
    logic [C_IN-1:0] in_total_bytes;
    logic [N_BYTES_IN-1:0] in_valid;
    logic in_last;
    logic input_pause;
    logic output_pause;

    axis_pack_input #(
        .DWIDTH_IN   (DWIDTH_IN )
    ) u_axis_pack_input(.*);

    logic [N-1:0][7:0] dout;
    logic [2*LOGN+2:0] out_meta;
    logic [N-1:0] out_vld;

    axis_pack_core #(
        .N_BYTES_IN  (N_BYTES_IN ),
        .N_BYTES_OUT (N_BYTES_OUT)
    ) u_axis_pack_core(.*);

    logic [DWIDTH_OUT-1:0] int_tdata;
    logic [DWIDTH_OUT/8-1:0] int_tkeep;
    logic int_tlast;
    logic int_tvalid;

    axis_pack_output #(
        .DWIDTH_OUT  (DWIDTH_OUT ),
        .N_BYTES_IN  (N_BYTES_IN ),
        .N_BYTES_OUT (N_BYTES_OUT)
    ) u_axis_pack_output(.*);

    axis_pack_out_fifo #(
        .N_BYTES_IN   (N_BYTES_IN ),
        .N_BYTES_OUT  (N_BYTES_OUT),
        .DWIDTH_OUT   (DWIDTH_OUT )
    ) u_axis_pack_out_fifo(.*);
endmodule