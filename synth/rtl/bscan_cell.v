module bc_1 (
    input  capture_clk,
    input  update_clk,
    input  capture_en,
    input  shift_en,
    input  update_en,
    input  si,
    output so,
    input  pin_in,
    output core_out
);
    reg capture_reg;
    reg update_reg;

    always @(posedge capture_clk) begin
        if (capture_en) capture_reg <= pin_in;
        else if (shift_en) capture_reg <= si;
    end

    always @(posedge update_clk) begin
        if (update_en) update_reg <= capture_reg;
    end

    assign so       = capture_reg;
    assign core_out = pin_in;
endmodule

module bc_2 (
    input  capture_clk,
    input  update_clk,
    input  capture_en,
    input  shift_en,
    input  update_en,
    input  extest,
    input  si,
    output so,
    input  core_in,
    output pin_out
);
    reg capture_reg;
    reg update_reg;

    always @(posedge capture_clk) begin
        if (capture_en) capture_reg <= core_in;
        else if (shift_en) capture_reg <= si;
    end

    always @(posedge update_clk) begin
        if (update_en) update_reg <= capture_reg;
    end

    assign so      = capture_reg;
    assign pin_out = extest ? update_reg : core_in;
endmodule

module bc_4 (
    input  capture_clk,
    input  update_clk,
    input  capture_en,
    input  shift_en,
    input  update_en,
    input  extest,
    input  si,
    output so,
    input  core_out,
    input  core_oe,
    inout  pad,
    output core_in
);
    reg data_cap, data_upd;
    reg oe_cap, oe_upd;

    always @(posedge capture_clk) begin
        if (capture_en) begin
            data_cap <= pad;
            oe_cap   <= core_oe;
        end else if (shift_en) begin
            oe_cap   <= si;
            data_cap <= oe_cap;
        end
    end

    always @(posedge update_clk) begin
        if (update_en) begin
            data_upd <= data_cap;
            oe_upd   <= oe_cap;
        end
    end

    assign so      = data_cap;
    assign core_in = pad;
    assign pad     = (extest ? oe_upd   : core_oe) ? (extest ? data_upd : core_out) : 1'bz;
endmodule

module bc_7 (
    input  capture_clk,
    input  shift_en,
    input  capture_en,
    input  si,
    output so,
    input  observe_in
);
    reg cap_reg;

    always @(posedge capture_clk) begin
        if (capture_en) cap_reg <= observe_in;
        else if (shift_en) cap_reg <= si;
    end

    assign so = cap_reg;
endmodule
