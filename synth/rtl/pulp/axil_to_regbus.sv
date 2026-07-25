`timescale 1ns/1ps
// AXI-Lite slave to reg_bus master adapter
// Serializes AXI-Lite read and write transactions into single-transaction reg_bus requests.
// Because reg_bus is single-transaction (no outstanding requests), write channels
// (AW + W) must both be valid before the adapter issues the request, and read
// transactions are handled one at a time. A 3-state FSM (IDLE, WRITE, READ)
// guarantees only one request is in-flight at a time.

module axil_to_regbus #(
  parameter type reg_req_t = logic,  // reg_bus request struct type (reg_bus_pkg::reg_req_t)
  parameter type reg_rsp_t = logic   // reg_bus response struct type (reg_bus_pkg::reg_rsp_t)
) (
  // Clock and reset (active-low synchronous reset)
  input  logic        clk,
  input  logic        rst_n,

  // AXI-Lite slave interface – write address channel
  input  logic [31:0] s_awaddr,
  input  logic        s_awvalid,
  output logic        s_awready,

  // AXI-Lite slave interface – write data channel
  input  logic [31:0] s_wdata,
  input  logic [3:0]  s_wstrb,
  input  logic        s_wvalid,
  output logic        s_wready,

  // AXI-Lite slave interface – write response channel
  output logic [1:0]  s_bresp,
  output logic        s_bvalid,
  input  logic        s_bready,

  // AXI-Lite slave interface – read address channel
  input  logic [31:0] s_araddr,
  input  logic        s_arvalid,
  output logic        s_arready,

  // AXI-Lite slave interface – read data channel
  output logic [31:0] s_rdata,
  output logic [1:0]  s_rresp,
  output logic        s_rvalid,
  input  logic        s_rready,

  // reg_bus master interface
  output reg_req_t    reg_req_o,
  input  reg_rsp_t    reg_rsp_i
);

  // ---------------------------------------------------------------------------
  // FSM state encoding
  // ---------------------------------------------------------------------------
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    WRITE = 2'b01,
    READ  = 2'b10
  } state_e;

  state_e state_q, state_d;

  // ---------------------------------------------------------------------------
  // Internal registers – latch AXI-Lite transaction fields
  // ---------------------------------------------------------------------------
  logic [31:0] awaddr_q;
  logic [31:0] wdata_q;
  logic [3:0]  wstrb_q;
  logic [31:0] araddr_q;

  // Response holding registers
  logic        bvalid_q;
  logic [31:0] rdata_q;
  logic        rvalid_q;
  logic        rsp_error_q;   // latched reg_rsp_i.error for read

  // ---------------------------------------------------------------------------
  // FSM – next-state logic (combinational)
  // ---------------------------------------------------------------------------
  always_comb begin
    state_d = state_q;

    case (state_q)
      IDLE: begin
        // Writes take priority: both AW and W must be valid to start
        if (s_awvalid && s_wvalid) begin
          state_d = WRITE;
        end else if (s_arvalid) begin
          state_d = READ;
        end
      end

      WRITE: begin
        // Stay in WRITE until the write-response handshake completes
        if (bvalid_q && s_bready) begin
          state_d = IDLE;
        end
      end

      READ: begin
        // Stay in READ until the read-data handshake completes
        if (rvalid_q && s_rready) begin
          state_d = IDLE;
        end
      end

      default: state_d = IDLE;
    endcase
  end

  // ---------------------------------------------------------------------------
  // FSM – sequential state and data registers
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q    <= IDLE;
      awaddr_q   <= '0;
      wdata_q    <= '0;
      wstrb_q    <= '0;
      araddr_q   <= '0;
      bvalid_q   <= 1'b0;
      rdata_q    <= '0;
      rvalid_q   <= 1'b0;
      rsp_error_q <= 1'b0;
    end else begin
      state_q <= state_d;

      case (state_q)
        // -----------------------------------------------------------------
        IDLE: begin
          // Clear response valids whenever we return to IDLE
          bvalid_q   <= 1'b0;
          rvalid_q   <= 1'b0;

          // Latch write transaction fields
          if (s_awvalid && s_wvalid) begin
            awaddr_q <= s_awaddr;
            wdata_q  <= s_wdata;
            wstrb_q  <= s_wstrb;
          end
          // Latch read transaction field
          if (s_arvalid && !(s_awvalid && s_wvalid)) begin
            araddr_q <= s_araddr;
          end
        end

        // -----------------------------------------------------------------
        WRITE: begin
          // When the reg_bus subordinate acknowledges, capture the response
          if (reg_req_o.valid && reg_rsp_i.ready) begin
            bvalid_q <= 1'b1;
          end
          // Clear bvalid once the master accepts the write response
          if (bvalid_q && s_bready) begin
            bvalid_q <= 1'b0;
          end
        end

        // -----------------------------------------------------------------
        READ: begin
          // When the reg_bus subordinate acknowledges, capture read data
          if (reg_req_o.valid && reg_rsp_i.ready) begin
            rdata_q    <= reg_rsp_i.rdata;
            rsp_error_q <= reg_rsp_i.error;
            rvalid_q   <= 1'b1;
          end
          // Clear rvalid once the master accepts the read data
          if (rvalid_q && s_rready) begin
            rvalid_q <= 1'b0;
          end
        end

        default: ;
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // reg_bus request – combinational drive
  // Valid is asserted until the subordinate acknowledges (ready goes high)
  // ---------------------------------------------------------------------------
  always_comb begin
    reg_req_o       = '0;   // default: deassert all fields

    case (state_q)
      WRITE: begin
        // Drive the write request while waiting for ready; deassert after ack
        if (!bvalid_q) begin
          reg_req_o.valid = 1'b1;
          reg_req_o.addr  = awaddr_q;
          reg_req_o.write = 1'b1;
          reg_req_o.wdata = wdata_q;
          reg_req_o.wstrb = wstrb_q;
        end
      end

      READ: begin
        // Drive the read request while waiting for ready; deassert after ack
        if (!rvalid_q) begin
          reg_req_o.valid = 1'b1;
          reg_req_o.addr  = araddr_q;
          reg_req_o.write = 1'b0;
          reg_req_o.wdata = '0;
          reg_req_o.wstrb = '0;
        end
      end

      default: ;
    endcase
  end

  // ---------------------------------------------------------------------------
  // AXI-Lite ready signals
  // AW and W are accepted in IDLE when both are valid (simultaneous handshake).
  // AR is accepted in IDLE when valid and no write is pending.
  // ---------------------------------------------------------------------------
  assign s_awready = (state_q == IDLE) &&  s_awvalid && s_wvalid;
  assign s_wready  = (state_q == IDLE) &&  s_awvalid && s_wvalid;
  assign s_arready = (state_q == IDLE) && !s_awvalid && s_arvalid;

  // ---------------------------------------------------------------------------
  // AXI-Lite write response channel
  // OKAY response (2'b00); propagate reg_bus error as SLVERR (2'b10) if needed
  // ---------------------------------------------------------------------------
  assign s_bresp  = 2'b00;   // OKAY – error signalling via pslverr is not mapped to AXI-Lite BRESP in this adapter
  assign s_bvalid = bvalid_q;

  // ---------------------------------------------------------------------------
  // AXI-Lite read data channel
  // ---------------------------------------------------------------------------
  assign s_rdata  = rdata_q;
  assign s_rresp  = rsp_error_q ? 2'b10 : 2'b00;  // SLVERR on reg_bus error, else OKAY
  assign s_rvalid = rvalid_q;

endmodule
