`timescale 1ns/1ps
// PULP Platform-compatible GPIO IP
// Register map:
//   0x00: PADDIR   (RW) - direction: 1=output, 0=input
//   0x04: PADIN    (RO) - synchronized input values
//   0x08: PADOUT   (RW) - output values
//   0x0C: INTEN    (RW) - interrupt enable per pin
//   0x10: INTTYPE0 (RW) - interrupt type bit 0
//   0x14: INTTYPE1 (RW) - interrupt type bit 1
//   0x18: INTSTATUS(RW1C) - interrupt status, cleared on read

module gpio_pulp
  import reg_bus_pkg::*;
#(
  parameter int unsigned N_GPIO   = 32,
  parameter type reg_req_t = reg_bus_pkg::reg_req_t,
  parameter type reg_rsp_t = reg_bus_pkg::reg_rsp_t
) (
  input  logic              clk_i,
  input  logic              rst_ni,
  input  logic [N_GPIO-1:0] gpio_in,
  output logic [N_GPIO-1:0] gpio_out,
  output logic [N_GPIO-1:0] gpio_tx_en_o,
  output logic [N_GPIO-1:0] gpio_in_sync_o,
  output logic              global_interrupt_o,
  output logic [N_GPIO-1:0] pin_level_interrupts_o,
  input  reg_req_t          reg_req_i,
  output reg_rsp_t          reg_rsp_o
);

  // -------------------------------------------------------------------------
  // Internal registers
  // -------------------------------------------------------------------------
  logic [N_GPIO-1:0] paddir;      // 0x00 - direction
  logic [N_GPIO-1:0] padout;      // 0x08 - output data
  logic [N_GPIO-1:0] inten;       // 0x0C - interrupt enable
  logic [N_GPIO-1:0] inttype0;    // 0x10 - interrupt type bit 0
  logic [N_GPIO-1:0] inttype1;    // 0x14 - interrupt type bit 1
  logic [N_GPIO-1:0] intstatus;   // 0x18 - interrupt status (RW1C)

  // 2-stage synchronizer for gpio_in
  logic [N_GPIO-1:0] padin_sync1;
  logic [N_GPIO-1:0] padin_sync2;
  // Previous synchronized value for edge detection
  logic [N_GPIO-1:0] padin_prev;

  // Edge detection
  logic [N_GPIO-1:0] rise_edge;
  logic [N_GPIO-1:0] fall_edge;

  // -------------------------------------------------------------------------
  // 2-stage input synchronizer
  // -------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      padin_sync1 <= '0;
      padin_sync2 <= '0;
    end else begin
      padin_sync1 <= gpio_in;
      padin_sync2 <= padin_sync1;
    end
  end

  // Previous value register for edge detection
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      padin_prev <= '0;
    end else begin
      padin_prev <= padin_sync2;
    end
  end

  // -------------------------------------------------------------------------
  // Edge detection (combinational)
  // -------------------------------------------------------------------------
  always_comb begin
    rise_edge = padin_sync2 & ~padin_prev;
    fall_edge = ~padin_sync2 & padin_prev;
  end

  // -------------------------------------------------------------------------
  // Interrupt status logic
  // -------------------------------------------------------------------------
  // Interrupt condition per pin based on inttype1:inttype0 encoding:
  //   {inttype1, inttype0} = 2'b00: level low
  //   {inttype1, inttype0} = 2'b10: level high
  //   {inttype1, inttype0} = 2'b01: falling edge
  //   {inttype1, inttype0} = 2'b11: rising edge
  logic [N_GPIO-1:0] int_condition;
  logic              intstatus_read;

  always_comb begin
    for (int i = 0; i < N_GPIO; i++) begin
      case ({inttype1[i], inttype0[i]})
        2'b00:   int_condition[i] = ~padin_sync2[i];   // level low
        2'b10:   int_condition[i] =  padin_sync2[i];   // level high
        2'b01:   int_condition[i] =  fall_edge[i];     // falling edge
        2'b11:   int_condition[i] =  rise_edge[i];     // rising edge
        default: int_condition[i] = 1'b0;
      endcase
    end
  end

  // intstatus_read: high when a valid read to address 0x18 occurs
  always_comb begin
    intstatus_read = reg_req_i.valid & ~reg_req_i.write &
                     (reg_req_i.addr[7:0] == 8'h18);
  end

  // Interrupt status register: set on condition, cleared on read of 0x18
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      intstatus <= '0;
    end else begin
      for (int i = 0; i < N_GPIO; i++) begin
        if (intstatus_read) begin
          // Clear on read
          intstatus[i] <= 1'b0;
        end else if (inten[i] & int_condition[i]) begin
          // Set when enabled interrupt condition is met
          intstatus[i] <= 1'b1;
        end
      end
    end
  end

  // -------------------------------------------------------------------------
  // Register write logic
  // -------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      paddir   <= '0;
      padout   <= '0;
      inten    <= '0;
      inttype0 <= '0;
      inttype1 <= '0;
    end else begin
      if (reg_req_i.valid & reg_req_i.write) begin
        case (reg_req_i.addr[7:0])
          8'h00: begin
            for (int b = 0; b < 4; b++) begin
              if (reg_req_i.wstrb[b]) paddir[b*8 +: 8] <= reg_req_i.wdata[b*8 +: 8];
            end
          end
          8'h08: begin
            for (int b = 0; b < 4; b++) begin
              if (reg_req_i.wstrb[b]) padout[b*8 +: 8] <= reg_req_i.wdata[b*8 +: 8];
            end
          end
          8'h0C: begin
            for (int b = 0; b < 4; b++) begin
              if (reg_req_i.wstrb[b]) inten[b*8 +: 8] <= reg_req_i.wdata[b*8 +: 8];
            end
          end
          8'h10: begin
            for (int b = 0; b < 4; b++) begin
              if (reg_req_i.wstrb[b]) inttype0[b*8 +: 8] <= reg_req_i.wdata[b*8 +: 8];
            end
          end
          8'h14: begin
            for (int b = 0; b < 4; b++) begin
              if (reg_req_i.wstrb[b]) inttype1[b*8 +: 8] <= reg_req_i.wdata[b*8 +: 8];
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
      case (reg_req_i.addr[7:0])
        8'h00: reg_rsp_o.rdata = 32'(paddir);
        8'h04: reg_rsp_o.rdata = 32'(padin_sync2);
        8'h08: reg_rsp_o.rdata = 32'(padout);
        8'h0C: reg_rsp_o.rdata = 32'(inten);
        8'h10: reg_rsp_o.rdata = 32'(inttype0);
        8'h14: reg_rsp_o.rdata = 32'(inttype1);
        8'h18: reg_rsp_o.rdata = 32'(intstatus);
        default: reg_rsp_o.rdata = 32'h0;
      endcase
    end
  end

  // -------------------------------------------------------------------------
  // Output assignments
  // -------------------------------------------------------------------------
  assign gpio_tx_en_o          = paddir;
  assign gpio_out               = padout;
  assign gpio_in_sync_o         = padin_sync2;
  assign global_interrupt_o     = |intstatus;
  assign pin_level_interrupts_o = intstatus & inten;

endmodule
