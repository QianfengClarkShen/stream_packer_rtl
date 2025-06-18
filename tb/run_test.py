import itertools
import os
import argparse
from pathlib import Path
import pytest
import random
from typing import List

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles
from cocotb.regression import TestFactory
from cocotb.utils import get_sim_time
from cocotb.queue import Queue
from cocotb.runner import get_runner
from cocotbext.axi import AxiStreamFrame, AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor

#module name
TOP_MODULE = "stream_packer"

class AXISMonitor:
    def __init__(self, axis_mon: AxiStreamMonitor):
        self.values = Queue[List[int]]()
        self._coro = None
        self.axis_mon = axis_mon
        self._pkt_cnt = 0

    def start(self) -> None:
        """Start monitor"""
        if self._coro is not None:
            raise RuntimeError("Monitor already started")
        self._coro = cocotb.start_soon(self._run())

    def stop(self) -> None:
        """Stop monitor"""
        if self._coro is None:
            raise RuntimeError("Monitor never started")
        self._coro.kill()
        self._coro = None

    def get_pkt_cnt(self) -> int:
        """Get the number of samples"""
        return self._pkt_cnt

    async def _run(self) -> None:
        while True:
            frame = await self.axis_mon.recv()
            #cocotb.log.info(f"Received AXIS frame: tdata={tdata}")
            self.values.put_nowait(frame.tdata)
            self._pkt_cnt += 1

class TB:
    def __init__(self, dut):
        self.dut = dut
        self.sparse_source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "sparse"), dut.clk)
        self.packed_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "packed"), dut.clk)
        self.sparse_mon = AXISMonitor(AxiStreamMonitor(AxiStreamBus.from_prefix(dut, "sparse"), dut.clk))
        self.packed_mon = AXISMonitor(self.packed_sink)
        self._checker = None

    def start(self) -> None:
        """Starts monitors, model, and checker coroutine"""
        if self._checker is not None:
            raise RuntimeError("Monitor already started")
        self.sparse_mon.start()
        self.packed_mon.start()
        self._checker = cocotb.start_soon(self._check())

    def stop(self) -> None:
        """Stops everything"""
        if self._checker is None:
            raise RuntimeError("Monitor never started")
        self.sparse_mon.stop()
        self.packed_mon.stop()
        self._checker.kill()
        self._checker = None

    def is_busy(self) -> bool:
        return self.sparse_mon.get_pkt_cnt() != self.packed_mon.get_pkt_cnt()

    async def _check(self) -> None:
        while True:
            actual_output = await self.packed_mon.values.get()
            expected_outputs = await self.sparse_mon.values.get()
            assert len(actual_output) == len(expected_outputs), f"\nOutput length mismatch: \nactual: {actual_output}, \nexpected: {expected_outputs}"
            for i in range(len(actual_output)):
                assert actual_output[i] == expected_outputs[i], f"\nOutput mismatch at index {i}: \nactual: {actual_output}, \nexpected: {expected_outputs}"


async def unit_test(dut,backpressure_rate):
    N_BYTES_IN = dut.N_BYTES_IN.value
    N_BYTES_OUT = dut.N_BYTES_OUT.value

    cocotb.start_soon(Clock(dut.clk, 2, units="ns").start())
    tb = TB(dut)

    dut._log.info("Initialize and reset model")

    # set backpressure level
    tb.packed_sink.set_pause_generator(itertools.cycle([random.random() < backpressure_rate for _ in range(100000)]))

    # Initial values
    dut.sparse_tdata.value = 0
    dut.sparse_tkeep.value = 0
    dut.sparse_tlast.value = 0
    dut.sparse_tvalid.value = 0

    dut.rst.value = 1
    await ClockCycles(dut.clk, 20)
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    #out of reset
    tb.start()
    dut._log.info("Test Started")

    #maximum packet size is 4.5 flits of the wider bus
    max_pkt_size = int(max(N_BYTES_IN,N_BYTES_OUT)*4.5)

    #sweep packet size from 1 byte to 4.5 flits of the wider bus
    for size in range(1,max_pkt_size+1):
        #3 packets for each size
        for _ in range(3):
            #generate tkeep for every flit
            valid_positions = set(random.sample(range(max_pkt_size), size))
            tkeep_list = [0] * max_pkt_size
            for i in range(max_pkt_size):
                if i in valid_positions:
                    tkeep_list[i] = 1
                else:
                    tkeep_list[i] = 0
            last_vld_byte = max(valid_positions)
            tkeep_list = tkeep_list[:last_vld_byte + 1]
            payload = bytearray(len(tkeep_list))
            for i in range(len(tkeep_list)):
                if tkeep_list[i]:
                    payload[i] = random.randbytes(1)[0]
                else:
                    payload[i] = 0
            frame = AxiStreamFrame(tdata=payload,tkeep=tkeep_list)
            await tb.sparse_source.send(frame)
    while get_sim_time(units="us") < 100:
        await RisingEdge(dut.clk)
        if not tb.is_busy():
            break
    await Timer(100, units="ns")
    dut._log.info("Test Finished")


@pytest.mark.parametrize("N_BYTES_IN", [4,8,16,32,64])
@pytest.mark.parametrize("N_BYTES_OUT", [4,8,16,32,64])
def test_runner(N_BYTES_IN, N_BYTES_OUT):
    sim = os.getenv("SIM", "verilator")

    proj_path = Path(__file__).resolve().parent.parent / "rtl"
    module_name = Path(__file__).stem

    verilog_sources = list(proj_path.rglob("*.sv")) + list(proj_path.rglob("*.v"))

    parameters = {
        "N_BYTES_IN": N_BYTES_IN,
        "N_BYTES_OUT": N_BYTES_OUT
    }

    runner = get_runner(sim)

    runner.build(
        hdl_toplevel=TOP_MODULE,
        verilog_sources=verilog_sources,
        parameters=parameters,
        waves=True,
        #build_args=["-Wno-lint", "-Wno-style", "-Wno-context", "-Wno-UNOPT", "+1800-2012ext+sv"],
        build_args=["-Wno-WIDTHEXPAND","+1800-2012ext+sv"],
        build_dir=f"sim_{N_BYTES_IN}_{N_BYTES_OUT}",
        always=True
    )

    runner.test(
        hdl_toplevel=TOP_MODULE,
        hdl_toplevel_lang="verilog",
        waves=True,
        test_module=module_name
    )

if cocotb.SIM_NAME:
    factory = TestFactory(unit_test)
    factory.add_option("backpressure_rate", [0, 0.3, 0.5, 0.9])
    factory.generate_tests()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run AXIS Pack tests")
    parser.add_argument("--N_BYTES_IN", type=int, default=4, help="Input AXIS data width in bytes")
    parser.add_argument("--N_BYTES_OUT", type=int, default=4, help="Output AXIS data width in bytes")
    args = parser.parse_args()

    test_runner(args.N_BYTES_IN, args.N_BYTES_OUT)