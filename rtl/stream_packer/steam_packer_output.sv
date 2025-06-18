`timescale 1ps/1ps

module axis_pack_output #(
    parameter int DWIDTH_OUT = 32,
    parameter int N_BYTES_IN = 4,
    parameter int N_BYTES_OUT = 4,
    parameter int N = 2**$clog2(N_BYTES_OUT+N_BYTES_IN),
    parameter int LOGN = $clog2(N)
) (
    input logic clk,
    input logic rst,
    input logic [N-1:0][7:0] dout,
    input logic [2*LOGN+2:0] out_meta,
    input logic [N-1:0] out_vld,
    output logic [DWIDTH_OUT-1:0] int_tdata,
    output logic [DWIDTH_OUT/8-1:0] int_tkeep,
    output logic int_tlast,
    output logic int_tvalid
);
    //internal buffer size
    localparam int N_BYTES_INT = N_BYTES_IN > N_BYTES_OUT ? N_BYTES_IN-1 : N_BYTES_OUT-1;

    logic [LOGN:0] leftover_bytes;
    logic [LOGN:0] curr_bytes;
    logic last;

    assign last = out_meta[0];
    assign curr_bytes = out_meta[LOGN+1:1];
    assign leftover_bytes = out_meta[2*LOGN+2:LOGN+2];

    //internal buffer should store partial output data when it's not a full flit
    logic [N_BYTES_INT-1:0][7:0] int_buffer;
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < N_BYTES_INT; i++)
                int_buffer[i] <= '0;
        end
        else if (curr_bytes >= N_BYTES_OUT) begin
            for (int i = N_BYTES_OUT; i < N_BYTES_OUT+N_BYTES_INT; i++) begin
                if (out_vld[i])
                    int_buffer[i-N_BYTES_OUT] <= dout[i];
                else if (N_BYTES_IN > N_BYTES_OUT)
                    int_buffer[i-N_BYTES_OUT] <= int_buffer[i];
            end
        end
        else begin
            for (int i = 0; i < N_BYTES_INT; i++)
                if (out_vld[i])
                    int_buffer[i] <= dout[i];
        end
    end

    //output data
    genvar i;
    if (N_BYTES_INT > N_BYTES_OUT) begin
        for (i = 0; i < N_BYTES_OUT; i++)
            assign int_tdata[i*8+7-:8] = i < leftover_bytes ? int_buffer[i] : dout[i];
    end
    else begin
        for (i = 0; i < N_BYTES_INT; i++)
            assign int_tdata[i*8+7-:8] = i < leftover_bytes ? int_buffer[i] : dout[i];
        for (i = N_BYTES_INT; i < N_BYTES_OUT; i++)
            assign int_tdata[i*8+7-:8] = dout[i];
    end
    for (i = 0; i < N_BYTES_OUT; i++)
        assign int_tkeep[i] = i < curr_bytes ? 1'b1 : 1'b0;
    assign int_tlast = last;
    assign int_tvalid = curr_bytes >= N_BYTES_OUT || last;
endmodule