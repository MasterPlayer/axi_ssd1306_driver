`timescale 1ps / 1ps


module axi_ssd1306_core #(
    parameter integer AXI_ADDR_WIDTH         = 32       ,
    parameter integer AXI_DATA_WIDTH         = 32       ,
    parameter         CLK_PERIOD             = 100000000,
    parameter         CLK_I2C_PERIOD         = 25000000 ,
    parameter         AXIS_DATA_WIDTH        = 32       ,
    parameter         AXIS_DEPTH             = 32       ,
    parameter         SIZE_WIDTH             = 8        ,
    parameter integer S_AXI_UCODE_ID_WIDTH   = 0        ,
    parameter integer S_AXI_UCODE_DATA_WIDTH = 32       ,
    parameter integer S_AXI_UCODE_ADDR_WIDTH = 8
) (
    input  logic                                  i_clk                ,
    input  logic                                  i_resetn             ,
    //
    input  logic                                  i_cfg_update_screen  ,
    input  logic [            AXI_ADDR_WIDTH-1:0] i_cfg_axi_baseaddress,
    input  logic [                           7:0] i_cfg_iic_address    ,
    input  logic                                  i_cfg_initialize     ,
    input  logic                                  i_cfg_selector       ,
    // input  logic [                     2:0] i_cfg_segment_limit  , // 4 or 8
    // interface to memory
    output logic [            AXI_ADDR_WIDTH-1:0] M_AXI_UPD_ARADDR       ,
    output logic [                           7:0] M_AXI_UPD_ARLEN        ,
    output logic [                           2:0] M_AXI_UPD_ARSIZE       ,
    output logic [                           1:0] M_AXI_UPD_ARBURST      ,
    output logic                                  M_AXI_UPD_ARVALID      ,
    input  logic                                  M_AXI_UPD_ARREADY      ,
    //
    input  logic [            AXI_DATA_WIDTH-1:0] M_AXI_UPD_RDATA        ,
    input  logic [                           1:0] M_AXI_UPD_RRESP        ,
    input  logic                                  M_AXI_UPD_RLAST        ,
    input  logic                                  M_AXI_UPD_RVALID       ,
    output logic                                  M_AXI_UPD_RREADY       ,
    //
    input  logic                                  S_AXI_UCODE_ACLK     ,
    input  logic                                  S_AXI_UCODE_ARESETN  ,
    input  logic [      S_AXI_UCODE_ID_WIDTH-1:0] S_AXI_UCODE_AWID     ,
    input  logic [    S_AXI_UCODE_ADDR_WIDTH-1:0] S_AXI_UCODE_AWADDR   ,
    input  logic [                           7:0] S_AXI_UCODE_AWLEN    ,
    input  logic [                           2:0] S_AXI_UCODE_AWSIZE   ,
    input  logic [                           1:0] S_AXI_UCODE_AWBURST  ,
    input  logic                                  S_AXI_UCODE_AWLOCK   ,
    input  logic [                           3:0] S_AXI_UCODE_AWCACHE  ,
    input  logic [                           2:0] S_AXI_UCODE_AWPROT   ,
    input  logic [                           3:0] S_AXI_UCODE_AWQOS    ,
    input  logic [                           3:0] S_AXI_UCODE_AWREGION ,
    input  logic                                  S_AXI_UCODE_AWVALID  ,
    output logic                                  S_AXI_UCODE_AWREADY  ,
    input  logic [    S_AXI_UCODE_DATA_WIDTH-1:0] S_AXI_UCODE_WDATA    ,
    input  logic [(S_AXI_UCODE_DATA_WIDTH/8)-1:0] S_AXI_UCODE_WSTRB    ,
    input  logic                                  S_AXI_UCODE_WLAST    ,
    input  logic                                  S_AXI_UCODE_WVALID   ,
    output logic                                  S_AXI_UCODE_WREADY   ,
    output logic [      S_AXI_UCODE_ID_WIDTH-1:0] S_AXI_UCODE_BID      ,
    output logic [                           1:0] S_AXI_UCODE_BRESP    ,
    output logic                                  S_AXI_UCODE_BVALID   ,
    input  logic                                  S_AXI_UCODE_BREADY   ,
    input  logic [      S_AXI_UCODE_ID_WIDTH-1:0] S_AXI_UCODE_ARID     ,
    input  logic [    S_AXI_UCODE_ADDR_WIDTH-1:0] S_AXI_UCODE_ARADDR   ,
    input  logic [                           7:0] S_AXI_UCODE_ARLEN    ,
    input  logic [                           2:0] S_AXI_UCODE_ARSIZE   ,
    input  logic [                           1:0] S_AXI_UCODE_ARBURST  ,
    input  logic                                  S_AXI_UCODE_ARLOCK   ,
    input  logic [                           3:0] S_AXI_UCODE_ARCACHE  ,
    input  logic [                           2:0] S_AXI_UCODE_ARPROT   ,
    input  logic [                           3:0] S_AXI_UCODE_ARQOS    ,
    input  logic [                           3:0] S_AXI_UCODE_ARREGION ,
    input  logic                                  S_AXI_UCODE_ARVALID  ,
    output logic                                  S_AXI_UCODE_ARREADY  ,
    output logic [      S_AXI_UCODE_ID_WIDTH-1:0] S_AXI_UCODE_RID      ,
    output logic [    S_AXI_UCODE_DATA_WIDTH-1:0] S_AXI_UCODE_RDATA    ,
    output logic [                           1:0] S_AXI_UCODE_RRESP    ,
    output logic                                  S_AXI_UCODE_RLAST    ,
    output logic                                  S_AXI_UCODE_RVALID   ,
    input  logic                                  S_AXI_UCODE_RREADY   ,
    //
    input  logic                                  i_scl_i              ,
    input  logic                                  i_sda_i              ,
    output logic                                  o_scl_t              ,
    output logic                                  o_sda_t
);


    logic [(AXIS_DATA_WIDTH-1):0] s_axis_tdata_bridge ;
    logic                         s_axis_tlast_bridge ;
    logic                         s_axis_tvalid_bridge;
    logic                         s_axis_tready_bridge;

    logic [           7:0] write_cmd_iic_addr_bridge;
    logic [SIZE_WIDTH-1:0] write_cmd_size_bridge    ;
    logic                  write_cmd_valid_bridge   ;


    logic [(AXIS_DATA_WIDTH-1):0] m_axis_tdata_ucode ;
    logic                         m_axis_tlast_ucode ;
    logic                         m_axis_tvalid_ucode;
    logic                         m_axis_tready_ucode;

    logic [           7:0] write_cmd_iic_addr_ucode;
    logic [SIZE_WIDTH-1:0] write_cmd_size_ucode    ;
    logic                  write_cmd_valid_ucode   ;

    // update interface
    logic [(AXIS_DATA_WIDTH-1):0] m_axis_tdata_update ;
    logic                         m_axis_tlast_update ;
    logic                         m_axis_tvalid_update;
    logic                         m_axis_tready_update;

    logic [           7:0] write_cmd_iic_addr_update;
    logic [SIZE_WIDTH-1:0] write_cmd_size_update    ;
    logic                  write_cmd_valid_update   ;



    axi_ssd1306_ucode_processor #(
        .S_AXI_ID_WIDTH  (S_AXI_UCODE_ID_WIDTH  ),
        .S_AXI_DATA_WIDTH(S_AXI_UCODE_DATA_WIDTH),
        .S_AXI_ADDR_WIDTH(S_AXI_UCODE_ADDR_WIDTH),
        .SIZE_WIDTH      (SIZE_WIDTH            ),
        .DATA_WIDTH      (AXIS_DATA_WIDTH       )
    ) axi_ssd1306_ucode_processor_inst (
        .i_clk             (i_clk                   ),
        .i_resetn          (i_resetn                ),
        .i_cfg_initialize  (i_cfg_initialize        ),
        .i_cfg_iic_address (i_cfg_iic_address       ),
        ///
        .WRITE_CMD_IIC_ADDR(write_cmd_iic_addr_ucode),
        .WRITE_CMD_SIZE    (write_cmd_size_ucode    ),
        .WRITE_CMD_VALID   (write_cmd_valid_ucode   ),
        //
        .M_AXIS_TDATA      (m_axis_tdata_ucode      ),
        .M_AXIS_TLAST      (m_axis_tlast_ucode      ),
        .M_AXIS_TVALID     (m_axis_tvalid_ucode     ),
        .M_AXIS_TREADY     (m_axis_tready_ucode     ),
        // Configuration loading bus
        .S_AXI_ACLK        (S_AXI_UCODE_ACLK        ),
        .S_AXI_ARESETN     (S_AXI_UCODE_ARESETN     ),
        .S_AXI_AWID        (S_AXI_UCODE_AWID        ),
        .S_AXI_AWADDR      (S_AXI_UCODE_AWADDR      ),
        .S_AXI_AWLEN       (S_AXI_UCODE_AWLEN       ),
        .S_AXI_AWSIZE      (S_AXI_UCODE_AWSIZE      ),
        .S_AXI_AWBURST     (S_AXI_UCODE_AWBURST     ),
        .S_AXI_AWLOCK      (S_AXI_UCODE_AWLOCK      ),
        .S_AXI_AWCACHE     (S_AXI_UCODE_AWCACHE     ),
        .S_AXI_AWPROT      (S_AXI_UCODE_AWPROT      ),
        .S_AXI_AWQOS       (S_AXI_UCODE_AWQOS       ),
        .S_AXI_AWREGION    (S_AXI_UCODE_AWREGION    ),
        .S_AXI_AWVALID     (S_AXI_UCODE_AWVALID     ),
        .S_AXI_AWREADY     (S_AXI_UCODE_AWREADY     ),
        .S_AXI_WDATA       (S_AXI_UCODE_WDATA       ),
        .S_AXI_WSTRB       (S_AXI_UCODE_WSTRB       ),
        .S_AXI_WLAST       (S_AXI_UCODE_WLAST       ),
        .S_AXI_WVALID      (S_AXI_UCODE_WVALID      ),
        .S_AXI_WREADY      (S_AXI_UCODE_WREADY      ),
        .S_AXI_BID         (S_AXI_UCODE_BID         ),
        .S_AXI_BRESP       (S_AXI_UCODE_BRESP       ),
        .S_AXI_BVALID      (S_AXI_UCODE_BVALID      ),
        .S_AXI_BREADY      (S_AXI_UCODE_BREADY      ),
        .S_AXI_ARID        (S_AXI_UCODE_ARID        ),
        .S_AXI_ARADDR      (S_AXI_UCODE_ARADDR      ),
        .S_AXI_ARLEN       (S_AXI_UCODE_ARLEN       ),
        .S_AXI_ARSIZE      (S_AXI_UCODE_ARSIZE      ),
        .S_AXI_ARBURST     (S_AXI_UCODE_ARBURST     ),
        .S_AXI_ARLOCK      (S_AXI_UCODE_ARLOCK      ),
        .S_AXI_ARCACHE     (S_AXI_UCODE_ARCACHE     ),
        .S_AXI_ARPROT      (S_AXI_UCODE_ARPROT      ),
        .S_AXI_ARQOS       (S_AXI_UCODE_ARQOS       ),
        .S_AXI_ARREGION    (S_AXI_UCODE_ARREGION    ),
        .S_AXI_ARVALID     (S_AXI_UCODE_ARVALID     ),
        .S_AXI_ARREADY     (S_AXI_UCODE_ARREADY     ),
        .S_AXI_RID         (S_AXI_UCODE_RID         ),
        .S_AXI_RDATA       (S_AXI_UCODE_RDATA       ),
        .S_AXI_RRESP       (S_AXI_UCODE_RRESP       ),
        .S_AXI_RLAST       (S_AXI_UCODE_RLAST       ),
        .S_AXI_RVALID      (S_AXI_UCODE_RVALID      ),
        .S_AXI_RREADY      (S_AXI_UCODE_RREADY      )
    );


    axi_ssd1306_update_processor #(
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH ),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH ),
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
        .AXIS_DEPTH     (AXIS_DEPTH     ),
        .SIZE_WIDTH     (SIZE_WIDTH     )
    ) axi_ssd1306_update_processor_inst (
        .i_clk                (i_clk                    ),
        .i_resetn             (i_resetn                 ),
        .i_cfg_axi_baseaddress(i_cfg_axi_baseaddress    ),
        .i_cfg_iic_address    (i_cfg_iic_address        ),
        .i_cfg_update_screen  (i_cfg_update_screen      ),
        // interface to memory
        .M_AXI_ARADDR         (M_AXI_UPD_ARADDR         ),
        .M_AXI_ARLEN          (M_AXI_UPD_ARLEN          ),
        .M_AXI_ARSIZE         (M_AXI_UPD_ARSIZE         ),
        .M_AXI_ARBURST        (M_AXI_UPD_ARBURST        ),
        .M_AXI_ARVALID        (M_AXI_UPD_ARVALID        ),
        .M_AXI_ARREADY        (M_AXI_UPD_ARREADY        ),
        .M_AXI_RDATA          (M_AXI_UPD_RDATA          ),
        .M_AXI_RRESP          (M_AXI_UPD_RRESP          ),
        .M_AXI_RLAST          (M_AXI_UPD_RLAST          ),
        .M_AXI_RVALID         (M_AXI_UPD_RVALID         ),
        .M_AXI_RREADY         (M_AXI_UPD_RREADY         ),
        //
        .WRITE_CMD_IIC_ADDR   (write_cmd_iic_addr_update),
        .WRITE_CMD_SIZE       (write_cmd_size_update    ),
        .WRITE_CMD_VALID      (write_cmd_valid_update   ),
        .M_AXIS_TDATA         (m_axis_tdata_update      ),
        .M_AXIS_TLAST         (m_axis_tlast_update      ),
        .M_AXIS_TVALID        (m_axis_tvalid_update     ),
        .M_AXIS_TREADY        (m_axis_tready_update     )
    );


    axis_ssd1306_mux #(
        .SIZE_WIDTH(SIZE_WIDTH     ),
        .DATA_WIDTH(AXIS_DATA_WIDTH)
    ) axis_ssd1306_mux_inst (
        .selector              (i_cfg_selector           ),
        // data channel 0 : from ucode
        .i_write_cmd_iic_addr_0(write_cmd_iic_addr_ucode ),
        .i_write_cmd_size_0    (write_cmd_size_ucode     ),
        .i_write_cmd_valid_0   (write_cmd_valid_ucode    ),
        //
        .i_s_axis_tdata_0      (m_axis_tdata_ucode       ),
        .i_s_axis_tlast_0      (m_axis_tlast_ucode       ),
        .i_s_axis_tvalid_0     (m_axis_tvalid_ucode      ),
        .o_s_axis_tready_0     (m_axis_tready_ucode      ),
        // data channel 1 : from internal logic
        .i_write_cmd_iic_addr_1(write_cmd_iic_addr_update),
        .i_write_cmd_size_1    (write_cmd_size_update    ),
        .i_write_cmd_valid_1   (write_cmd_valid_update   ),
        //
        .i_s_axis_tdata_1      (m_axis_tdata_update      ),
        .i_s_axis_tlast_1      (m_axis_tlast_update      ),
        .i_s_axis_tvalid_1     (m_axis_tvalid_update     ),
        .o_s_axis_tready_1     (m_axis_tready_update     ),
        // to iic bridge
        .o_write_cmd_iic_addr  (write_cmd_iic_addr_bridge),
        .o_write_cmd_size      (write_cmd_size_bridge    ),
        .o_write_cmd_valid     (write_cmd_valid_bridge   ),
        //
        .o_m_axis_tdata        (s_axis_tdata_bridge      ),
        .o_m_axis_tlast        (s_axis_tlast_bridge      ),
        .o_m_axis_tvalid       (s_axis_tvalid_bridge     ),
        .i_m_axis_tready       (s_axis_tready_bridge     )
        //
    );


    axis_iic_bridge_cmd #(
        .CLK_PERIOD    (CLK_PERIOD     ),
        .CLK_I2C_PERIOD(CLK_I2C_PERIOD ),
        .DATA_WIDTH    (AXIS_DATA_WIDTH),
        .DEPTH         (AXIS_DEPTH     ),
        .SIZE_WIDTH    (SIZE_WIDTH     )
    ) axis_iic_bridge_cmd_inst (
        .i_clk               (i_clk                    ),
        .i_reset             (~i_resetn                ),
        //
        .i_write_cmd_iic_addr(write_cmd_iic_addr_bridge),
        .i_write_cmd_size    (write_cmd_size_bridge    ),
        .i_write_cmd_valid   (write_cmd_valid_bridge   ),
        //
        .i_s_axis_tdata      (s_axis_tdata_bridge      ),
        .i_s_axis_tkeep      (1'b1                     ),
        .i_s_axis_tlast      (s_axis_tlast_bridge      ),
        .i_s_axis_tvalid     (s_axis_tvalid_bridge     ),
        .o_s_axis_tready     (s_axis_tready_bridge     ),
        //
        .i_read_cmd_iic_addr ('0                       ),
        .i_read_cmd_size     ('0                       ),
        .i_read_cmd_valid    (1'b0                     ),
        //
        .o_m_axis_tdata      (                         ),
        .o_m_axis_tkeep      (                         ),
        .o_m_axis_tlast      (                         ),
        .o_m_axis_tvalid     (                         ),
        .i_m_axis_tready     (1'b0                     ),
        //
        .i_scl_i             (i_scl_i                  ),
        .i_sda_i             (i_sda_i                  ),
        .o_scl_t             (o_scl_t                  ),
        .o_sda_t             (o_sda_t                  )
    );




endmodule