`timescale 1ps/1ps
module sw2 #(
    parameter int DWIDTH = 8,
    parameter int AWIDTH = 2,
    parameter int REGISTER = 1
) (
    input logic clk,
    input logic [DWIDTH-1:0] din0,
    input logic [AWIDTH-1:0] dst_in0,
    input logic in_vld0,
    input logic [DWIDTH-1:0] din1,
    input logic [AWIDTH-1:0] dst_in1,
    input logic in_vld1,
    output logic [DWIDTH-1:0] dout0,
    output logic [AWIDTH-1:0] dst_out0,
    output logic out_vld0,
    output logic [DWIDTH-1:0] dout1,
    output logic [AWIDTH-1:0] dst_out1,
    output logic out_vld1
);
    logic [AWIDTH-1:0] new_dst0;
    logic [AWIDTH-1:0] new_dst1;

    assign new_dst0 = {1'b0, dst_in0[AWIDTH-1:1]};
    assign new_dst1 = {1'b0, dst_in1[AWIDTH-1:1]};

    if (REGISTER[0]) begin
        always_ff @(posedge clk) begin
            if (~in_vld0 && ~in_vld1) begin
                out_vld0 <= 1'b0;
                out_vld1 <= 1'b0;
            end
            else if (~in_vld0) begin
                dout0 <= din1;
                dout1 <= din1;
                dst_out0 <= new_dst1;
                dst_out1 <= new_dst1;
                out_vld0 <= ~dst_in1[0];
                out_vld1 <= dst_in1[0];
            end
            else if (~in_vld1) begin
                dout0 <= din0;
                dout1 <= din0;
                dst_out0 <= new_dst0;
                dst_out1 <= new_dst0;
                out_vld0 <= ~dst_in0[0];
                out_vld1 <= dst_in0[0];
            end
            else begin
                dout0 <= dst_in0[0] ? din1 : din0;
                dout1 <= dst_in0[0] ? din0 : din1;
                dst_out0 <= dst_in0[0] ? new_dst1 : new_dst0;
                dst_out1 <= dst_in0[0] ? new_dst0 : new_dst1;
                out_vld0 <= 1'b1;
                out_vld1 <= 1'b1;
            end
        end
    end
    else begin
        always_comb begin
            if (~in_vld0 && ~in_vld1) begin
                dout0 = '0;
                dout1 = '0;
                dst_out0 = '0;
                dst_out1 = '0;
                out_vld0 = 1'b0;
                out_vld1 = 1'b0;
            end
            else if (~in_vld0) begin
                dout0 = din1;
                dout1 = din1;
                dst_out0 = new_dst1;
                dst_out1 = new_dst1;
                out_vld0 = ~dst_in1[0];
                out_vld1 = dst_in1[0];
            end
            else if (~in_vld1) begin
                dout0 = din0;
                dout1 = din0;
                dst_out0 = new_dst0;
                dst_out1 = new_dst0;
                out_vld0 = ~dst_in0[0];
                out_vld1 = dst_in0[0];
            end
            else begin
                dout0 = dst_in0[0] ? din1 : din0;
                dout1 = dst_in0[0] ? din0 : din1;
                dst_out0 = dst_in0[0] ? new_dst1 : new_dst0;
                dst_out1 = dst_in0[0] ? new_dst0 : new_dst1;
                out_vld0 = 1'b1;
                out_vld1 = 1'b1;
            end
        end
    end
endmodule