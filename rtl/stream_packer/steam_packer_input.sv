`timescale 1ps/1ps

module axis_pack_input #(
    //data width
    parameter int DWIDTH_IN = 32,
    //number of input bytes
    parameter int N_BYTES_IN = DWIDTH_IN/8,
    //bitwidth of input bytes
    parameter int C_IN = $clog2(N_BYTES_IN+1)
) (
    input logic clk,
    input logic rst,
    input logic [DWIDTH_IN-1:0] sparse_tdata,
    input logic [DWIDTH_IN/8-1:0] sparse_tkeep,
    input logic sparse_tlast,
    input logic sparse_tvalid,
    output logic sparse_tready,
    output logic [N_BYTES_IN-1:0][7:0] in_data,
    output logic [N_BYTES_IN-1:0][C_IN-1:0] in_bytes,
    output logic [C_IN-1:0] in_total_bytes,
    output logic [N_BYTES_IN-1:0] in_valid,
    output logic in_last,
//backpressure signals
    input logic input_pause,
    input logic output_pause
);
//helper function to calculate the sum of the first n bits of input TKEEP
    function automatic int sum(input logic [N_BYTES_IN-1:0] in_data,input int n);
        int cnt = 0;
        for (int i = 0; i < n; i++)
            cnt = cnt + in_data[i];
        return cnt;
    endfunction

    logic [N_BYTES_IN-1:0][C_IN-1:0] int_bytes;
//calculate the number of bytes in the input flit
    always_comb begin
        for (int i = 0; i < N_BYTES_IN; i++) begin
            int int_bytes_tmp;
            int_bytes_tmp = sum(sparse_tkeep,i+1);
            int_bytes[i] = int_bytes_tmp[C_IN-1:0];
        end
    end

//use a ping pong FIFO to improve timing
    //tdata + tkeep + bytes + tlast
    logic [DWIDTH_IN+N_BYTES_IN+N_BYTES_IN*C_IN:0] fifo_in_tdata;
    logic fifo_in_tvalid;
    logic fifo_in_tready;
    logic [DWIDTH_IN+N_BYTES_IN+N_BYTES_IN*C_IN:0] fifo_out_tdata;
    logic fifo_out_tvalid;
    logic fifo_out_tready;

    assign sparse_tready = fifo_in_tready;
    assign fifo_in_tdata = {sparse_tlast, int_bytes, sparse_tkeep, sparse_tdata};
    assign fifo_in_tvalid = sparse_tvalid;

    assign in_data = fifo_out_tdata[DWIDTH_IN-1:0];
    assign in_valid = fifo_out_tvalid ? fifo_out_tdata[DWIDTH_IN+N_BYTES_IN-1:DWIDTH_IN] : '0;
    genvar i;
    //in_bytes are used to calculate the banyan destination for each input byte
    assign in_bytes[0] = '0;
    for (i = 1; i < N_BYTES_IN; i++)
        assign in_bytes[i] = fifo_out_tdata[DWIDTH_IN+N_BYTES_IN+C_IN*i-1-:C_IN];
    //total number of bytres in the input flit
    assign in_total_bytes = fifo_out_tvalid ? fifo_out_tdata[DWIDTH_IN+N_BYTES_IN+C_IN*N_BYTES_IN-1-:C_IN] : '0;
    assign in_last = fifo_out_tvalid && fifo_out_tdata[DWIDTH_IN+N_BYTES_IN+N_BYTES_IN*C_IN];
    assign fifo_out_tready = ~input_pause && ~output_pause;

    pingpong_buf #(
        .DWIDTH (DWIDTH_IN+N_BYTES_IN+N_BYTES_IN*C_IN+1)
    ) u_pingpong_buf(
        .*,
        .s_axis_tdata  (fifo_in_tdata   ),
        .s_axis_tvalid (fifo_in_tvalid  ),
        .s_axis_tready (fifo_in_tready  ),
        .m_axis_tdata  (fifo_out_tdata  ),
        .m_axis_tvalid (fifo_out_tvalid ),
        .m_axis_tready (fifo_out_tready )
    );
endmodule