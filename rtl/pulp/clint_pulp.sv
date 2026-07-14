`timescale 1ns/1ps
// PULP Platform-compatible CLINT (Core-Local Interruptor)
// RISC-V CLINT register map (2 harts):
//   0x0000: msip[0]        (RW, 1-bit) - hart 0 software interrupt
//   0x0004: msip[1]        (RW, 1-bit) - hart 1 software interrupt
//   0x4000: mtimecmp_lo[0] (RW, 32-bit)
//   0x4004: mtimecmp_hi[0] (RW, 32-bit)
//   0x4008: mtimecmp_lo[1] (RW, 32-bit)
//   0x400C: mtimecmp_hi[1] (RW, 32-bit)
//   0xBFF8: mtime_lo       (RW, 32-bit)
//   0xBFFC: mtime_hi       (RW, 32-bit)

module clint_pulp
  import reg_bus_pkg::*;
#(
  parameter type reg_req_t = reg_bus_pkg::reg_req_t,
  parameter type reg_rsp_t = reg_bus_pkg::reg_rsp_t
) (
  input  logic       clk_i,
  input  logic       rst_ni,
  input  logic       testmode_i,
  input  reg_req_t   reg_req_i,
  output reg_rsp_t   reg_rsp_o,
  input  logic       rtc_i,
  output logic [1:0] timer_irq_o,
  output logic [1:0] ipi_o
);

  // -------------------------------------------------------------------------
  // Internal registers
  // -------------------------------------------------------------------------
  logic        msip     [2];          // Software interrupt pending per hart
  logic [63:0] mtimecmp [2];          // Timer compare per hart
  logic [63:0] mtime;                 // Global timer counter

  // -------------------------------------------------------------------------
  // RTC 2-stage synchronizer + edge detect
  // -------------------------------------------------------------------------
  logic rtc_sync1, rtc_sync2, rtc_prev;
  logic rtc_rise;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rtc_sync1 <= 1'b0;
      rtc_sync2 <= 1'b0;
      rtc_prev  <= 1'b0;
    end else begin
      rtc_sync1 <= rtc_i;
      rtc_sync2 <= rtc_sync1;
      rtc_prev  <= rtc_sync2;
    end
  end

  always_comb begin
    rtc_rise = rtc_sync2 & ~rtc_prev;
  end

  // -------------------------------------------------------------------------
  // mtime counter — increment on RTC rising edge
  // -------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mtime <= 64'h0;
    end else begin
      if (rtc_rise) begin
        mtime <= mtime + 64'h1;
      end
      // Allow software write to mtime via reg bus (handled in write block below)
    end
  end

  // -------------------------------------------------------------------------
  // Register write logic
  // -------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      msip[0]      <= 1'b0;
      msip[1]      <= 1'b0;
      mtimecmp[0]  <= 64'hFFFFFFFFFFFFFFFF;
      mtimecmp[1]  <= 64'hFFFFFFFFFFFFFFFF;
    end else begin
      if (reg_req_i.valid & reg_req_i.write) begin
        case (reg_req_i.addr[15:0])
          // msip[0]: 0x0000
          16'h0000: begin
            if (reg_req_i.wstrb[0]) msip[0] <= reg_req_i.wdata[0];
          end
          // msip[1]: 0x0004
          16'h0004: begin
            if (reg_req_i.wstrb[0]) msip[1] <= reg_req_i.wdata[0];
          end
          // mtimecmp_lo[0]: 0x4000
          16'h4000: begin
            for (int b = 0; b < 4; b++) begin
              if (reg_req_i.wstrb[b]) mtimecmp[0][b*8 +: 8] <= reg_req_i.wdata[b*8 +: 8];
            end
          end
          // mtimecmp_hi[0]: 0x4004
          16'h4004: begin
            for (int b = 0; b < 4; b++) begin
              if (reg_req_i.wstrb[b]) mtimecmp[0][32 + b*8 +: 8] <= reg_req_i.wdata[b*8 +: 8];
            end
          end
          // mtimecmp_lo[1]: 0x4008
          16'h4008: begin
            for (int b = 0; b < 4; b++) begin
              if (reg_req_i.wstrb[b]) mtimecmp[1][b*8 +: 8] <= reg_req_i.wdata[b*8 +: 8];
            end
          end
          // mtimecmp_hi[1]: 0x400C
          16'h400C: begin
            for (int b = 0; b < 4; b++) begin
              if (reg_req_i.wstrb[b]) mtimecmp[1][32 + b*8 +: 8] <= reg_req_i.wdata[b*8 +: 8];
            end
          end
          // mtime_lo: 0xBFF8
          16'hBFF8: begin
            for (int b = 0; b < 4; b++) begin
              if (reg_req_i.wstrb[b]) mtime[b*8 +: 8] <= reg_req_i.wdata[b*8 +: 8];
            end
          end
          // mtime_hi: 0xBFFC
          16'hBFFC: begin
            for (int b = 0; b < 4; b++) begin
              if (reg_req_i.wstrb[b]) mtime[32 + b*8 +: 8] <= reg_req_i.wdata[b*8 +: 8];
            end
          end
          default: ;
        endcase
      end
    end
  end

  // -------------------------------------------------------------------------
  // Register read logic (combinational)
  // -------------------------------------------------------------------------
  always_comb begin
    reg_rsp_o.ready = 1'b1;
    reg_rsp_o.error = 1'b0;
    reg_rsp_o.rdata = 32'h0;

    if (reg_req_i.valid & ~reg_req_i.write) begin
      case (reg_req_i.addr[15:0])
        16'h0000: reg_rsp_o.rdata = {31'h0, msip[0]};
        16'h0004: reg_rsp_o.rdata = {31'h0, msip[1]};
        16'h4000: reg_rsp_o.rdata = mtime[31:0];          // mtimecmp_lo[0]
        16'h4004: reg_rsp_o.rdata = mtimecmp[0][63:32];   // mtimecmp_hi[0]
        16'h4008: reg_rsp_o.rdata = mtimecmp[1][31:0];    // mtimecmp_lo[1]
        16'h400C: reg_rsp_o.rdata = mtimecmp[1][63:32];   // mtimecmp_hi[1]
        16'hBFF8: reg_rsp_o.rdata = mtime[31:0];          // mtime_lo
        16'hBFFC: reg_rsp_o.rdata = mtime[63:32];         // mtime_hi
        default:  reg_rsp_o.rdata = 32'h0;
      endcase
    end
  end

  // -------------------------------------------------------------------------
  // Timer interrupt outputs: timer_irq_o[h] = (mtime >= mtimecmp[h])
  // -------------------------------------------------------------------------
  always_comb begin
    for (int h = 0; h < 2; h++) begin
      timer_irq_o[h] = (mtime >= mtimecmp[h]) ? 1'b1 : 1'b0;
    end
  end

  // -------------------------------------------------------------------------
  // Software interrupt outputs: ipi_o[h] = msip[h]
  // -------------------------------------------------------------------------
  always_comb begin
    for (int h = 0; h < 2; h++) begin
      ipi_o[h] = msip[h];
    end
  end

endmodule
