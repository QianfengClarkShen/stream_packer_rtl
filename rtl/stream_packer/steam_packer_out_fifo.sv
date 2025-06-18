`timescale 1ps/1ps

module axis_pack_out_fifo # (
    parameter int N_BYTES_IN = 4,
    parameter int N_BYTES_OUT = 4,
    parameter int DWIDTH_OUT = 32
) (
    input logic clk,
    input logic rst,
    input logic [DWIDTH_OUT-1:0] int_tdata,
    input logic [DWIDTH_OUT/8-1:0] int_tkeep,
    input logic int_tlast,
    input logic int_tvalid,
    output logic output_pause,
    output logic [DWIDTH_OUT-1:0] packed_tdata,
    output logic [DWIDTH_OUT/8-1:0] packed_tkeep,
    output logic packed_tlast,
    output logic packed_tvalid,
    input logic packed_tready
);
    //output buffer should be able to hold 16 input flits
    //max banyan latency should not be larger than 8 cycles
    //issue backpressure when the output FIFO is half full
    //this way we can avoid implementing clock enable for the whole banyan network
    localparam int DEPTH = 2**$clog2((16*N_BYTES_IN-1)/N_BYTES_OUT+1) < 32 ? 32 : 2**$clog2((16*N_BYTES_IN-1)/N_BYTES_OUT+1);
    localparam int N = $clog2(DEPTH);

    logic [DWIDTH_OUT*9/8:0] fifo_in_tdata;
    logic fifo_in_tvalid;
    logic [DWIDTH_OUT*9/8:0] fifo_out_tdata;
    logic fifo_out_tvalid;
    logic fifo_out_tready;
    logic half_full;
    assign fifo_in_tdata = {int_tlast, int_tkeep, int_tdata};
    assign fifo_in_tvalid = int_tvalid;
    assign packed_tdata = fifo_out_tdata[DWIDTH_OUT-1:0];
    assign packed_tkeep = fifo_out_tdata[DWIDTH_OUT*9/8-1:DWIDTH_OUT];
    assign packed_tlast = fifo_out_tdata[DWIDTH_OUT*9/8];
    assign packed_tvalid = fifo_out_tvalid;
    assign fifo_out_tready = packed_tready;

    //issue output pause when the output FIFO is half full
    assign output_pause = half_full;

    easy_fifo #(
        .DWIDTH (DWIDTH_OUT*9/8+1),
        .DEPTH  (DEPTH),
        .N      (N)
    ) u_easy_fifo(
        .*,
        .s_axis_tdata  (fifo_in_tdata   ),
        .s_axis_tvalid (fifo_in_tvalid  ),
        .s_axis_tready (                ),
        .m_axis_tdata  (fifo_out_tdata  ),
        .m_axis_tvalid (fifo_out_tvalid ),
        .m_axis_tready (fifo_out_tready )
    );
endmodule