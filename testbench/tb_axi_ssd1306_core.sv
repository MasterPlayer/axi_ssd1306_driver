

`timescale 1ps / 1ps


module tb_axi_ssd1306_core ();

    parameter integer AXI_ADDR_WIDTH   = 32       ;
    parameter integer AXI_DATA_WIDTH   = 32       ;
    parameter         CLK_PERIOD       = 100000000;
    parameter         CLK_I2C_PERIOD   = 10000000 ;
    parameter         AXIS_DATA_WIDTH  = 8        ;
    parameter         AXIS_DEPTH       = 16       ;
    parameter         SIZE_WIDTH       = 8        ;
    parameter integer S_AXI_ID_WIDTH   = 0        ;
    parameter integer S_AXI_DATA_WIDTH = 32       ;
    parameter integer S_AXI_ADDR_WIDTH = 8        ;

    logic i_clk   ;
    logic i_resetn;
    //
    logic                      i_cfg_update_screen   = 1'b0        ;
    logic [AXI_ADDR_WIDTH-1:0] i_cfg_axi_baseaddress = '{default:0};
    logic [               7:0] i_cfg_iic_address     = 8'h78       ;
    logic                      i_cfg_initialize      = 1'b0        ;
    logic                      i_cfg_selector        = 1'b0        ;
    // interface to memory
    logic [AXI_ADDR_WIDTH-1:0] o_m_axi_araddr ;
    logic [               7:0] o_m_axi_arlen  ;
    logic [               2:0] o_m_axi_arsize ;
    logic [               1:0] o_m_axi_arburst;
    logic                      o_m_axi_arvalid;
    logic                      i_m_axi_arready;
    //
    logic [AXI_DATA_WIDTH-1:0] i_m_axi_rdata ;
    logic [               1:0] i_m_axi_rresp ;
    logic                      i_m_axi_rlast ;
    logic                      i_m_axi_rvalid;
    logic                      o_m_axi_rready;
    //
    logic [      S_AXI_ID_WIDTH-1:0] i_axi_awid    ;
    logic [    S_AXI_ADDR_WIDTH-1:0] i_axi_awaddr  ;
    logic [                     7:0] i_axi_awlen   ;
    logic [                     2:0] i_axi_awsize  ;
    logic [                     1:0] i_axi_awburst ;
    logic                            i_axi_awlock  ;
    logic [                     3:0] i_axi_awcache ;
    logic [                     2:0] i_axi_awprot  ;
    logic [                     3:0] i_axi_awqos   ;
    logic [                     3:0] i_axi_awregion;
    logic                            i_axi_awvalid ;
    logic                            i_axi_awready ;
    logic [    S_AXI_DATA_WIDTH-1:0] i_axi_wdata   ;
    logic [(S_AXI_DATA_WIDTH/8)-1:0] i_axi_wstrb   ;
    logic                            i_axi_wlast   ;
    logic                            i_axi_wvalid  ;
    logic                            i_axi_wready  ;
    logic [      S_AXI_ID_WIDTH-1:0] i_axi_bid     ;
    logic [                     1:0] i_axi_bresp   ;
    logic                            i_axi_bvalid  ;
    logic                            i_axi_bready  ;
    logic [      S_AXI_ID_WIDTH-1:0] i_axi_arid    ;
    logic [    S_AXI_ADDR_WIDTH-1:0] i_axi_araddr  ;
    logic [                     7:0] i_axi_arlen   ;
    logic [                     2:0] i_axi_arsize  ;
    logic [                     1:0] i_axi_arburst ;
    logic                            i_axi_arlock  ;
    logic [                     3:0] i_axi_arcache ;
    logic [                     2:0] i_axi_arprot  ;
    logic [                     3:0] i_axi_arqos   ;
    logic [                     3:0] i_axi_arregion;
    logic                            i_axi_arvalid ;
    logic                            i_axi_arready ;
    logic [      S_AXI_ID_WIDTH-1:0] i_axi_rid     ;
    logic [    S_AXI_DATA_WIDTH-1:0] i_axi_rdata   ;
    logic [                     1:0] i_axi_rresp   ;
    logic                            i_axi_rlast   ;
    logic                            i_axi_rvalid  ;
    logic                            i_axi_rready  ;
    //
    logic scl_i;
    logic sda_i;
    logic scl_t;
    logic sda_t;

    initial begin 
        i_clk = 1'b0;
        forever 
        #5000 i_clk = ~i_clk;
    end 

    integer index = 0;

    always_ff @(posedge i_clk) begin 
        index <= index + 1;
    end 


    always_ff @(posedge i_clk) begin : i_resetn_processing 
        if (index < 100) begin 
            i_resetn <= 1'b0;
        end else begin 
            i_resetn <= 1'b1;
        end 
    end 

    always_comb i_axi_awburst = 2'b01;
    always_comb i_axi_awsize = 3'b010;
    always_comb i_axi_awlen = 8'h0B;
    always_comb i_axi_wstrb = 4'hF;

    always_ff @(posedge i_clk) begin 
        case (index)
            1000    : begin i_axi_awaddr <= 32'h00000000; i_axi_awvalid <= 1'b1; i_axi_wdata <= 32'h833FA800; i_axi_wvalid <= 1'b1; i_axi_wlast <= 1'b0; i_axi_bready <= 1'b0; end
            1001    : begin i_axi_awaddr <= 32'h00000000; i_axi_awvalid <= 1'b1; i_axi_wdata <= 32'h833FA800; i_axi_wvalid <= 1'b1; i_axi_wlast <= 1'b0; i_axi_bready <= 1'b0; end
            1002    : begin i_axi_awaddr <= 32'h00000000; i_axi_awvalid <= 1'b1; i_axi_wdata <= 32'h833FA800; i_axi_wvalid <= 1'b1; i_axi_wlast <= 1'b0; i_axi_bready <= 1'b0; end
            1003    : begin i_axi_awaddr <= 32'h00000000; i_axi_awvalid <= 1'b0; i_axi_wdata <= 32'h833FA800; i_axi_wvalid <= 1'b1; i_axi_wlast <= 1'b0; i_axi_bready <= 1'b0; end
            1004    : begin i_axi_awaddr <= 32'h00000000; i_axi_awvalid <= 1'b0; i_axi_wdata <= 32'h8300D300; i_axi_wvalid <= 1'b1; i_axi_wlast <= 1'b0; i_axi_bready <= 1'b0; end
            1005    : begin i_axi_awaddr <= 32'h00000000; i_axi_awvalid <= 1'b0; i_axi_wdata <= 32'h82FF4000; i_axi_wvalid <= 1'b1; i_axi_wlast <= 1'b0; i_axi_bready <= 1'b0; end
            1006    : begin i_axi_awaddr <= 32'h00000000; i_axi_awvalid <= 1'b0; i_axi_wdata <= 32'h82FFA000; i_axi_wvalid <= 1'b1; i_axi_wlast <= 1'b0; i_axi_bready <= 1'b0; end
            1007    : begin i_axi_awaddr <= 32'h00000000; i_axi_awvalid <= 1'b0; i_axi_wdata <= 32'h82FFC000; i_axi_wvalid <= 1'b1; i_axi_wlast <= 1'b0; i_axi_bready <= 1'b0; end
            1008    : begin i_axi_awaddr <= 32'h00000000; i_axi_awvalid <= 1'b0; i_axi_wdata <= 32'h8302DA00; i_axi_wvalid <= 1'b1; i_axi_wlast <= 1'b0; i_axi_bready <= 1'b0; end
            1009    : begin i_axi_awaddr <= 32'h00000000; i_axi_awvalid <= 1'b0; i_axi_wdata <= 32'h837F8100; i_axi_wvalid <= 1'b1; i_axi_wlast <= 1'b0; i_axi_bready <= 1'b0; end
            1010    : begin i_axi_awaddr <= 32'h00000000; i_axi_awvalid <= 1'b0; i_axi_wdata <= 32'h82FFA400; i_axi_wvalid <= 1'b1; i_axi_wlast <= 1'b0; i_axi_bready <= 1'b0; end
            1011    : begin i_axi_awaddr <= 32'h00000000; i_axi_awvalid <= 1'b0; i_axi_wdata <= 32'h82FFA600; i_axi_wvalid <= 1'b1; i_axi_wlast <= 1'b0; i_axi_bready <= 1'b0; end
            1012    : begin i_axi_awaddr <= 32'h00000000; i_axi_awvalid <= 1'b0; i_axi_wdata <= 32'h8380D500; i_axi_wvalid <= 1'b1; i_axi_wlast <= 1'b0; i_axi_bready <= 1'b0; end
            1013    : begin i_axi_awaddr <= 32'h00000000; i_axi_awvalid <= 1'b0; i_axi_wdata <= 32'h83148D00; i_axi_wvalid <= 1'b1; i_axi_wlast <= 1'b0; i_axi_bready <= 1'b0; end
            1014    : begin i_axi_awaddr <= 32'h00000000; i_axi_awvalid <= 1'b0; i_axi_wdata <= 32'h82FFAF00; i_axi_wvalid <= 1'b1; i_axi_wlast <= 1'b1; i_axi_bready <= 1'b0; end
            default : begin i_axi_awaddr <= 32'h00000000; i_axi_awvalid <= 1'b0; i_axi_wdata <= 32'h00000000; i_axi_wvalid <= 1'b0; i_axi_wlast <= 1'b0; i_axi_bready <= 1'b1; end
        endcase
    end 


    always_ff @(posedge i_clk) begin : i_cfg_initialize_processing
        case (index)
            2000    : i_cfg_initialize <= 1'b1;
            default : i_cfg_initialize <= 1'b0;
        endcase
    end  


    always_ff @(posedge i_clk) begin : i_cfg_iic_address_processing
        case (index)
            1000    : i_cfg_iic_address <= 8'h78;
            default : i_cfg_iic_address <= i_cfg_iic_address;
        endcase // index
    end 

    axi_ssd1306_core #(
        .AXI_ADDR_WIDTH  (AXI_ADDR_WIDTH  ),
        .AXI_DATA_WIDTH  (AXI_DATA_WIDTH  ),
        .CLK_PERIOD      (CLK_PERIOD      ),
        .CLK_I2C_PERIOD  (CLK_I2C_PERIOD  ),
        .AXIS_DATA_WIDTH (AXIS_DATA_WIDTH ),
        .AXIS_DEPTH      (AXIS_DEPTH      ),
        .SIZE_WIDTH      (SIZE_WIDTH      ),
        .S_AXI_ID_WIDTH  (S_AXI_ID_WIDTH  ),
        .S_AXI_DATA_WIDTH(S_AXI_DATA_WIDTH),
        .S_AXI_ADDR_WIDTH(S_AXI_ADDR_WIDTH)
    ) axi_ssd1306_core_inst (
        .i_clk                (i_clk                ),
        .i_resetn             (i_resetn             ),
        //
        .i_cfg_update_screen  (i_cfg_update_screen  ),
        .i_cfg_axi_baseaddress(i_cfg_axi_baseaddress),
        .i_cfg_iic_address    (i_cfg_iic_address    ),
        .i_cfg_initialize     (i_cfg_initialize     ),
        .i_cfg_selector       (i_cfg_selector       ),
        // interface to memory
        .o_m_axi_araddr       (o_m_axi_araddr       ),
        .o_m_axi_arlen        (o_m_axi_arlen        ),
        .o_m_axi_arsize       (o_m_axi_arsize       ),
        .o_m_axi_arburst      (o_m_axi_arburst      ),
        .o_m_axi_arvalid      (o_m_axi_arvalid      ),
        .i_m_axi_arready      (i_m_axi_arready      ),
        //
        .i_m_axi_rdata        (i_m_axi_rdata        ),
        .i_m_axi_rresp        (i_m_axi_rresp        ),
        .i_m_axi_rlast        (i_m_axi_rlast        ),
        .i_m_axi_rvalid       (i_m_axi_rvalid       ),
        .o_m_axi_rready       (o_m_axi_rready       ),
        //
        .S_AXI_ACLK           (i_clk                ),
        .S_AXI_ARESETN        (i_resetn             ),
        .S_AXI_AWID           (i_axi_awid           ),
        .S_AXI_AWADDR         (i_axi_awaddr         ),
        .S_AXI_AWLEN          (i_axi_awlen          ),
        .S_AXI_AWSIZE         (i_axi_awsize         ),
        .S_AXI_AWBURST        (i_axi_awburst        ),
        .S_AXI_AWLOCK         (i_axi_awlock         ),
        .S_AXI_AWCACHE        (i_axi_awcache        ),
        .S_AXI_AWPROT         (i_axi_awprot         ),
        .S_AXI_AWQOS          (i_axi_awqos          ),
        .S_AXI_AWREGION       (i_axi_awregion       ),
        .S_AXI_AWVALID        (i_axi_awvalid        ),
        .S_AXI_AWREADY        (i_axi_awready        ),
        .S_AXI_WDATA          (i_axi_wdata          ),
        .S_AXI_WSTRB          (i_axi_wstrb          ),
        .S_AXI_WLAST          (i_axi_wlast          ),
        .S_AXI_WVALID         (i_axi_wvalid         ),
        .S_AXI_WREADY         (i_axi_wready         ),
        .S_AXI_BID            (i_axi_bid            ),
        .S_AXI_BRESP          (i_axi_bresp          ),
        .S_AXI_BVALID         (i_axi_bvalid         ),
        .S_AXI_BREADY         (i_axi_bready         ),
        .S_AXI_ARID           (i_axi_arid           ),
        .S_AXI_ARADDR         (i_axi_araddr         ),
        .S_AXI_ARLEN          (i_axi_arlen          ),
        .S_AXI_ARSIZE         (i_axi_arsize         ),
        .S_AXI_ARBURST        (i_axi_arburst        ),
        .S_AXI_ARLOCK         (i_axi_arlock         ),
        .S_AXI_ARCACHE        (i_axi_arcache        ),
        .S_AXI_ARPROT         (i_axi_arprot         ),
        .S_AXI_ARQOS          (i_axi_arqos          ),
        .S_AXI_ARREGION       (i_axi_arregion       ),
        .S_AXI_ARVALID        (i_axi_arvalid        ),
        .S_AXI_ARREADY        (i_axi_arready        ),
        .S_AXI_RID            (i_axi_rid            ),
        .S_AXI_RDATA          (i_axi_rdata          ),
        .S_AXI_RRESP          (i_axi_rresp          ),
        .S_AXI_RLAST          (i_axi_rlast          ),
        .S_AXI_RVALID         (i_axi_rvalid         ),
        .S_AXI_RREADY         (i_axi_rready         ),
        //
        .i_scl_i              (scl_i                ),
        .i_sda_i              (sda_i                ),
        .o_scl_t              (scl_t                ),
        .o_sda_t              (sda_t                )
    );


    tb_slave_device_model tb_slave_device_model_inst (
        .i_clk    (i_clk    ),
        .i_reset  (~i_resetn),
        .iic_scl_i(scl_t    ),
        .iic_sda_i(sda_t    ),
        .iic_scl_o(scl_i    ),
        .iic_sda_o(sda_i    )
    );


endmodule 