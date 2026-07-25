`timescale 1ns/1ps
// PULP Platform register bus package
// Defines reg_req_t and reg_rsp_t structs used by GPIO, PLIC, CLINT IPs
package reg_bus_pkg;

  typedef struct packed {
    logic [31:0] addr;
    logic        write;
    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic        valid;
  } reg_req_t;

  typedef struct packed {
    logic [31:0] rdata;
    logic        error;
    logic        ready;
  } reg_rsp_t;

endpackage
