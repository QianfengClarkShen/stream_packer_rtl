`timescale 1ps/1ps
module pingpong_buf #(
	parameter int DWIDTH = 32
) (
	input logic clk,
	input logic rst,
	input logic [DWIDTH-1:0] s_axis_tdata,
	input logic s_axis_tvalid,
    output logic s_axis_tready,
	output logic [DWIDTH-1:0] m_axis_tdata,
	output logic m_axis_tvalid,
    input logic m_axis_tready
);
	logic [DWIDTH-1:0] mem_int[1:0];
	logic rd_addr;
	logic wr_addr;
    logic [1:0] rd_ptr;
    logic [1:0] wr_ptr;
    logic [1:0] queue_size;
    assign queue_size = wr_ptr - rd_ptr;

    logic core_rdy;

	always_ff @(posedge clk) begin
		if (rst) begin
			rd_ptr <= '0;
			wr_ptr <= '0;
            m_axis_tvalid <= 1'b0;
            s_axis_tready <= 1'b1;
		end
		else begin
			if (s_axis_tvalid && s_axis_tready) begin
				mem_int[wr_addr] <= s_axis_tdata;
				wr_ptr <= wr_ptr + 1'b1;
			end
			if (core_rdy && rd_ptr != wr_ptr)
				rd_ptr <= rd_ptr + 1'b1;

            if (core_rdy)
                s_axis_tready <= 1'b1;
            else if (s_axis_tvalid && (queue_size == 'b1))
                s_axis_tready <= 1'b0;
            if (s_axis_tvalid)
                m_axis_tvalid <= 1'b1;
            else if (core_rdy && (queue_size == 'b1))
                m_axis_tvalid <= 1'b0;
		end
	end

    assign core_rdy = m_axis_tready || ~m_axis_tvalid;

	assign wr_addr = wr_ptr[0];
	assign rd_addr = rd_ptr[0];

//output
    assign m_axis_tdata = mem_int[rd_addr];
endmodule