`timescale 1ps/1ps
module easy_fifo #(
	parameter int DWIDTH = 32,
	parameter int DEPTH	= 32,
    parameter int N = $clog2(DEPTH)
) (
	input logic clk,
	input logic rst,
	input logic [DWIDTH-1:0] s_axis_tdata,
	input logic s_axis_tvalid,
    output logic s_axis_tready,
	output logic [DWIDTH-1:0] m_axis_tdata,
	output logic m_axis_tvalid,
    input logic m_axis_tready,
    output logic half_full
);
	logic [DWIDTH-1:0] mem_int[DEPTH-1:0];
	logic [N-1:0] rd_addr;
	logic [N-1:0] wr_addr;
    logic [N:0] rd_ptr;
    logic [N:0] wr_ptr;
    logic [N:0] queue_size;
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
            else if (s_axis_tvalid && (queue_size == DEPTH-1))
                s_axis_tready <= 1'b0;
            if (s_axis_tvalid)
                m_axis_tvalid <= 1'b1;
            else if (core_rdy && (queue_size == 'b1))
                m_axis_tvalid <= 1'b0;
		end
	end

//issue output pause when the output FIFO is half full
    always_ff @(posedge clk) begin
        if (rst)
            half_full <= 1'b0;
        else
            half_full <= queue_size >= DEPTH/2;
    end

    assign core_rdy = m_axis_tready || ~m_axis_tvalid;

	assign wr_addr = wr_ptr[N-1:0];
	assign rd_addr = rd_ptr[N-1:0];

//output
    assign m_axis_tdata = mem_int[rd_addr];

`ifdef DUMP_WAVE
    initial begin
        $dumpfile("dump.vcd");
        for (int i = 0; i < DEPTH; i++) begin
            $dumpvars(0, mem_int[i]);
        end
    end
`endif
endmodule