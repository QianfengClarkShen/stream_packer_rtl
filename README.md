# stream_packer_rtl

Systemverilog source for AXI4-Stream sparse-to-dense packer

## Overview

This repository contains the SystemVerilog source code for an AXI4-Stream sparse-to-dense packer. The module is designed to efficiently pack sparse data streams into dense streams, eleminating TKEEP bubbles in the AXI-Stream packets.

## Features

- **AXI4-Stream Compliant**: Fully adheres to the AXI4-Stream protocol. Supported fields: TDATA, TVALID, TREADY, TKEEP, TLAST.
- **Configurable Parameters**: Supports parameterized input and output bus width.
- **High Performance**: Designed for high Fmax.
- **Resource Efficient**: Using Banyan Network inside, optimized for FPGA resource utilization.

## TOP Level RTL

The top level module resides in file `rtl/stream_packer/steam_packer.sv`, it is defined as below:

```verilog
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
sparse_t****: Input sparse AXI Stream signals, TKEEP may contain bubbles
packed_t****: Output packed AXI Stream signals, TKEEP contains no bubble
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
```

## Usage

- Clone the repository:

```bash
git clone https://github.com/your-repo/stream_packer_rtl.git
cd stream_packer_rtl
```

- Include folder `rtl` in your project to integrate the `stream_packer` module into your design.

## File Structure

- `rtl/`: Contains the SystemVerilog source files for the stream packer.
- `tb/`: Includes cocotb testbench for simulation.
- `syn/`: Include vivado synthesis script to synthesize the design.
- `README.md`: Project documentation.

## Toolchain dependency

Run simulation:

- Verilator 5.022 or later
- Python 3.9 or later
- Python modules: cocotb 1.9.2, cocotbext.axi, pytest

Generate synthesis report:

- Vivado 2024.1 or later.

## Run imulation

Make sure dependecy for simulation is satisfied

```bash
cd stream_packer_rtl/tb
pytest
```

## Generate synthesis report

Make sure Vivado is installed and the binary executable `vivado` is in your system $PATH.

```bash
cd stream_packer_rtl/syn
make
```

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

## Contact

For questions or support, please contact [email@clarkshen.com]
