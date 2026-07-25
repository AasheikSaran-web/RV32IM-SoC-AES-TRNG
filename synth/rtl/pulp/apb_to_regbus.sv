`timescale 1ns/1ps
// APB slave to reg_bus master adapter
// Bridges an APB master to the PULP Platform reg_bus interface used by GPIO, PLIC, and CLINT IPs.
// On the APB setup phase (psel && !penable), the module drives reg_req_o.valid and latches the
// address, direction, write data, and byte strobes. It holds valid asserted through the APB access
// phase (psel && penable) until the reg_bus subordinate acknowledges with reg_rsp_i.ready.

module apb_to_regbus #(
  parameter type reg_req_t = logic,  // reg_bus request struct type (reg_bus_pkg::reg_req_t)
  parameter type reg_rsp_t = logic   // reg_bus response struct type (reg_bus_pkg::reg_rsp_t)
) (
  // APB slave interface
  input  logic        pclk,
  input  logic        presetn,
  input  logic [31:0] paddr,
  input  logic        psel,
  input  logic        penable,
  input  logic        pwrite,
  input  logic [31:0] pwdata,
  input  logic [3:0]  pstrb,
  output logic [31:0] prdata,
  output logic        pready,
  output logic        pslverr,

  // reg_bus master interface
  output reg_req_t    reg_req_o,
  input  reg_rsp_t    reg_rsp_i
);

  // ---------------------------------------------------------------------------
  // Internal registers – latch APB transaction fields at setup phase entry
  // ---------------------------------------------------------------------------
  logic [31:0] addr_q;
  logic        write_q;
  logic [31:0] wdata_q;
  logic [3:0]  wstrb_q;

  // One-bit flag that tracks whether we are inside an active APB transfer.
  // Set on the setup phase, cleared when the subordinate accepts the request.
  logic        req_pending_q;

  // ---------------------------------------------------------------------------
  // Latch on setup phase: psel asserted, penable not yet asserted
  // ---------------------------------------------------------------------------
  always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      addr_q        <= '0;
      write_q       <= 1'b0;
      wdata_q       <= '0;
      wstrb_q       <= '0;
      req_pending_q <= 1'b0;
    end else begin
      // Setup phase: sample the address and control signals
      if (psel && !penable) begin
        addr_q        <= paddr;
        write_q       <= pwrite;
        wdata_q       <= pwdata;
        wstrb_q       <= pstrb;
        req_pending_q <= 1'b1;
      end
      // Clear pending flag once the reg_bus subordinate acknowledges
      if (req_pending_q && reg_rsp_i.ready) begin
        req_pending_q <= 1'b0;
      end
    end
  end

  // ---------------------------------------------------------------------------
  // reg_bus request – combinational drive
  // Valid is asserted from the setup phase through until the subordinate is ready
  // ---------------------------------------------------------------------------
  always_comb begin
    reg_req_o       = '0;                                   // default: all zeros
    // During setup phase drive directly from APB inputs; during access phase
    // use latched values so signals are stable while waiting for ready.
    if (psel && !penable) begin
      // Setup phase: present the new request immediately
      reg_req_o.valid = 1'b1;
      reg_req_o.addr  = paddr;
      reg_req_o.write = pwrite;
      reg_req_o.wdata = pwdata;
      reg_req_o.wstrb = pstrb;
    end else if (req_pending_q) begin
      // Access phase: hold the latched values until acknowledged
      reg_req_o.valid = 1'b1;
      reg_req_o.addr  = addr_q;
      reg_req_o.write = write_q;
      reg_req_o.wdata = wdata_q;
      reg_req_o.wstrb = wstrb_q;
    end
  end

  // ---------------------------------------------------------------------------
  // APB response – driven combinationally from reg_bus response
  // ---------------------------------------------------------------------------
  assign prdata  = reg_rsp_i.rdata;
  assign pready  = reg_rsp_i.ready;
  assign pslverr = reg_rsp_i.error;

endmodule
