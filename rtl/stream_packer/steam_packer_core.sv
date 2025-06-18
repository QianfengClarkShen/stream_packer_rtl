`timescale 1ps/1ps

module axis_pack_core #(
    //number of input bytes and output bytes
    parameter int N_BYTES_IN = 4,
    parameter int N_BYTES_OUT = 4,
    parameter int C_IN = $clog2(N_BYTES_IN+1),
    //size of the banyan network
    parameter int N = 2**$clog2(N_BYTES_OUT+N_BYTES_IN),
    parameter int LOGN = $clog2(N)
) (
    input logic clk,
    input logic rst,
    input logic [N_BYTES_IN-1:0][7:0] in_data,
    input logic [N_BYTES_IN-1:0][C_IN-1:0] in_bytes,
    input logic [C_IN-1:0] in_total_bytes,
    input logic [N_BYTES_IN-1:0] in_valid,
    input logic in_last,
    input logic output_pause,
    output logic input_pause,
    output logic [N-1:0][7:0] dout,
    output logic [2*LOGN+2:0] out_meta,
    output logic [N-1:0] out_vld
);
    logic [LOGN:0] leftover_bytes;
    logic [LOGN:0] curr_bytes;
    logic last_reg;

    assign curr_bytes = (input_pause || output_pause) ? leftover_bytes : (leftover_bytes + in_total_bytes);

    logic last;
    assign last = ~input_pause && ~output_pause && in_last;

/*
    - Banyan network
*/
    //signals to the banyan network
    logic [N-1:0][7:0] din;
    logic [N-1:0] in_vld;
    logic [N-1:0][LOGN-1:0] dst_in;

    genvar i;
    for (i = 0; i < N_BYTES_IN; i++)
        assign din[i] = in_data[i];
    for (i = N_BYTES_IN; i < N; i++)
        assign din[i] = '0;
    assign in_vld[N_BYTES_IN-1:0] = (input_pause || output_pause) ? '0 : in_valid[N_BYTES_IN-1:0];
    assign in_vld[N-1:N_BYTES_IN] = '0;

    //calculate the destination for each input byte
    always_comb begin
        for (int i = 0; i < N_BYTES_IN; i++)
            dst_in[i] = leftover_bytes[LOGN-1:0] + in_bytes[i];
        for (int i = N_BYTES_IN; i < N; i++)
            dst_in[i] = '0;
    end
    banyan #(
        .N      (N      ),
        .DWIDTH (8      ),
        .LOGN   (LOGN   )
    ) u_banyan(.*);

/*
    - Control logic
*/
    //calculate the number of leftover bytes each cycle
    always_ff @(posedge clk) begin
        if (rst)
            leftover_bytes <= '0;
        else if (curr_bytes >= N_BYTES_OUT)
            leftover_bytes <= curr_bytes - N_BYTES_OUT[LOGN:0];
        else if (last || last_reg)
            leftover_bytes <= '0;
        else
            leftover_bytes <= curr_bytes;
    end

    //last reg logic
    always_ff @(posedge clk) begin
        if (rst)
            last_reg <= 1'b0;
        else
            last_reg <= (last || last_reg) && curr_bytes > N_BYTES_OUT;
    end

    //backpressure logic
    //pause input when we already seen a tlast and the current bytes are more than one flit
    //or when the current bytes are more than two flits
    always_ff @( posedge clk ) begin
        if (rst)
            input_pause <= 1'b0;
        else
            input_pause <= (curr_bytes > N_BYTES_OUT) && (last_reg || last) || (curr_bytes >= 2*N_BYTES_OUT);
    end

    logic real_last;
    assign real_last = (last_reg || last) && curr_bytes <= N_BYTES_OUT && curr_bytes != '0;

    logic [2*LOGN+2:0] in_meta;
    assign in_meta = {leftover_bytes, curr_bytes, real_last};

    //latency = roundup(LOGN/2)
    localparam int BANYAN_LATENCY = LOGN/2;

    shift_register #(
        .DWIDTH (2*LOGN+3),
        .DEPTH  (BANYAN_LATENCY)
    ) u_shift_register(
        .*,
        .din  (in_meta),
        .dout (out_meta)
    );
endmodule