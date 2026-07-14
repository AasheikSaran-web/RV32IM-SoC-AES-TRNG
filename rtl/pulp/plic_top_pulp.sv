`timescale 1ns/1ps
// PULP Platform-compatible PLIC (Platform-Level Interrupt Controller)
// Simplified RISC-V PLIC spec register map:
//   0x000000 + 4*i : source i priority (3 bits)
//   0x001000       : interrupt pending bits (RO, sources 0-31)
//   0x002000       : target 0 enable bits (sources 0-31)
//   0x200000       : target 0 priority threshold (3 bits)
//   0x200004       : target 0 claim/complete register

module plic_top_pulp
  import reg_bus_pkg::*;
#(
  parameter int N_SOURCE  = 16,
  parameter int N_TARGET  = 1,
  parameter int MAX_PRIO  = 7,
  parameter type reg_req_t = reg_bus_pkg::reg_req_t,
  parameter type reg_rsp_t = reg_bus_pkg::reg_rsp_t
) (
  input  logic              clk_i,
  input  logic              rst_ni,
  input  reg_req_t          req_i,
  output reg_rsp_t          resp_o,
  input  logic [N_SOURCE-1:0] le_i,            // 1=edge triggered, 0=level triggered
  input  logic [N_SOURCE-1:0] irq_sources_i,
  output logic [N_TARGET-1:0] eip_targets_o
);

  // -------------------------------------------------------------------------
  // Parameter derivation
  // -------------------------------------------------------------------------
  localparam int PRIO_BITS = 3;

  // -------------------------------------------------------------------------
  // Internal registers
  // -------------------------------------------------------------------------
  logic [PRIO_BITS-1:0] ip_prio   [N_SOURCE];  // Source priority registers
  logic                 ie        [N_TARGET][N_SOURCE]; // Interrupt enable per target per source
  logic [PRIO_BITS-1:0] threshold [N_TARGET];  // Priority threshold per target
  logic [N_SOURCE-1:0]  pending;               // Interrupt pending bits
  logic [N_SOURCE-1:0]  irq_prev;              // Previous irq for edge detection
  logic [N_SOURCE-1:0]  claimed;               // Tracks which sources are claimed (not yet completed)

  // Claim register per target: holds the ID of the highest-priority claimed interrupt
  logic [$clog2(N_SOURCE+1)-1:0] claim_reg [N_TARGET];

  // -------------------------------------------------------------------------
  // Pending bit logic
  // -------------------------------------------------------------------------
  // For edge-triggered (le_i=1): set pending on rising edge, clear on complete
  // For level-triggered (le_i=0): pending follows irq_sources_i (and is cleared on complete)
  logic [N_SOURCE-1:0] irq_rise;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      irq_prev <= '0;
    end else begin
      irq_prev <= irq_sources_i;
    end
  end

  always_comb begin
    irq_rise = irq_sources_i & ~irq_prev;
  end

  // -------------------------------------------------------------------------
  // Write decode helpers
  // -------------------------------------------------------------------------
  // Address ranges:
  //   Priority:   32'h000000 .. 32'h000000 + 4*(N_SOURCE-1)
  //   Pending:    32'h001000 (read-only)
  //   IE[0]:      32'h002000
  //   Threshold0: 32'h200000
  //   Claim/Cmp0: 32'h200004

  logic        wr_valid;
  logic        rd_valid;
  logic [31:0] wr_addr;
  logic [31:0] rd_addr;
  logic [31:0] wr_data;

  always_comb begin
    wr_valid = req_i.valid &  req_i.write;
    rd_valid = req_i.valid & ~req_i.write;
    wr_addr  = req_i.addr;
    rd_addr  = req_i.addr;
    wr_data  = req_i.wdata;
  end

  // -------------------------------------------------------------------------
  // Register writes (always_ff)
  // -------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int i = 0; i < N_SOURCE; i++) ip_prio[i] <= '0;
      for (int t = 0; t < N_TARGET; t++) begin
        threshold[t] <= '0;
        claim_reg[t] <= '0;
        for (int i = 0; i < N_SOURCE; i++) ie[t][i] <= 1'b0;
      end
      pending <= '0;
      claimed <= '0;
    end else begin
      // -----------------------------------------------------------------------
      // Pending bit updates
      // -----------------------------------------------------------------------
      for (int i = 0; i < N_SOURCE; i++) begin
        if (le_i[i]) begin
          // Edge-triggered: set on rising edge
          if (irq_rise[i]) pending[i] <= 1'b1;
        end else begin
          // Level-triggered: follow irq level (unless claimed/being completed)
          if (!claimed[i]) pending[i] <= irq_sources_i[i];
        end
      end

      // -----------------------------------------------------------------------
      // Register-mapped writes
      // -----------------------------------------------------------------------
      if (wr_valid) begin
        // Source priority registers: 0x000000 + 4*i
        if (wr_addr[23:16] == 8'h00 && wr_addr[15:12] == 4'h0) begin
          // Address range 0x000000..0x000FFC
          automatic int src_idx;
          src_idx = int'(wr_addr[11:2]); // word index = addr[11:2]
          if (src_idx < N_SOURCE) begin
            ip_prio[src_idx] <= wr_data[PRIO_BITS-1:0];
          end
        end

        // IE target 0: 0x002000
        if (wr_addr == 32'h002000) begin
          for (int i = 0; i < N_SOURCE && i < 32; i++) begin
            ie[0][i] <= wr_data[i];
          end
        end

        // Threshold target 0: 0x200000
        if (wr_addr == 32'h200000) begin
          threshold[0] <= wr_data[PRIO_BITS-1:0];
        end

        // Claim/complete target 0: 0x200004 — write = complete
        if (wr_addr == 32'h200004) begin
          automatic int cmp_id;
          cmp_id = int'(wr_data[$clog2(N_SOURCE+1)-1:0]);
          if (cmp_id > 0 && cmp_id < N_SOURCE) begin
            // Complete: clear pending and claimed
            pending[cmp_id] <= 1'b0;
            claimed[cmp_id] <= 1'b0;
          end
        end
      end

      // -----------------------------------------------------------------------
      // Claim read: 0x200004 — read = claim highest-priority pending+enabled src
      // -----------------------------------------------------------------------
      if (rd_valid && rd_addr == 32'h200004) begin
        // Find highest priority enabled pending source above threshold
        automatic logic [$clog2(N_SOURCE+1)-1:0] best_id;
        automatic logic [PRIO_BITS-1:0]           best_prio;
        best_id   = '0;
        best_prio = threshold[0];
        for (int i = 1; i < N_SOURCE; i++) begin
          if (pending[i] && ie[0][i] && (ip_prio[i] > best_prio)) begin
            best_prio = ip_prio[i];
            best_id   = $clog2(N_SOURCE+1)'(i);
          end
        end
        claim_reg[0] <= best_id;
        if (best_id != '0) begin
          claimed[best_id] <= 1'b1;
          pending[best_id] <= 1'b0;
        end
      end
    end
  end

  // -------------------------------------------------------------------------
  // EIP (external interrupt pending) output — combinational
  // -------------------------------------------------------------------------
  always_comb begin
    for (int t = 0; t < N_TARGET; t++) begin
      eip_targets_o[t] = 1'b0;
      for (int i = 1; i < N_SOURCE; i++) begin
        if (pending[i] && ie[t][i] && (ip_prio[i] > threshold[t])) begin
          eip_targets_o[t] = 1'b1;
        end
      end
    end
  end

  // -------------------------------------------------------------------------
  // Register read — combinational
  // -------------------------------------------------------------------------
  always_comb begin
    resp_o.ready = 1'b1;
    resp_o.error = 1'b0;
    resp_o.rdata = 32'h0;

    if (rd_valid) begin
      // Source priority registers: 0x000000 + 4*i
      if (rd_addr[23:12] == 12'h000) begin
        automatic int src_idx;
        src_idx = int'(rd_addr[11:2]);
        if (src_idx < N_SOURCE) begin
          resp_o.rdata = 32'(ip_prio[src_idx]);
        end
      end
      // Pending bits: 0x001000
      if (rd_addr == 32'h001000) begin
        resp_o.rdata = 32'(pending);
      end
      // IE target 0: 0x002000
      if (rd_addr == 32'h002000) begin
        for (int i = 0; i < 32; i++) begin
          if (i < N_SOURCE)
            resp_o.rdata[i] = ie[0][i];
          else
            resp_o.rdata[i] = 1'b0;
        end
      end
      // Threshold target 0: 0x200000
      if (rd_addr == 32'h200000) begin
        resp_o.rdata = 32'(threshold[0]);
      end
      // Claim/complete target 0: 0x200004
      if (rd_addr == 32'h200004) begin
        resp_o.rdata = 32'(claim_reg[0]);
      end
    end
  end

endmodule
