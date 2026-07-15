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
    output logic [            AXI_ADDR_WIDTH-1:0] o_m_axi_araddr       ,
    output logic [                           7:0] o_m_axi_arlen        ,
    output logic [                           2:0] o_m_axi_arsize       ,
    output logic [                           1:0] o_m_axi_arburst      ,
    output logic                                  o_m_axi_arvalid      ,
    input  logic                                  i_m_axi_arready      ,
    //
    input  logic [            AXI_DATA_WIDTH-1:0] i_m_axi_rdata        ,
    input  logic [                           1:0] i_m_axi_rresp        ,
    input  logic                                  i_m_axi_rlast        ,
    input  logic                                  i_m_axi_rvalid       ,
    output logic                                  o_m_axi_rready       ,
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

    typedef enum {
        IDLE_ST,
        ESTABLISH_ADDRESS_ST, 
        AWAIT_DATA_ST,

        TX_CMD_SET_SEGMENT_ADDRESS_ST,
        TX_CMD_SET_DATA_ST,
        TX_DATA_ST, 
        CHECK_SEGMENT_ADDRESS_ST,

        STUB_ST
    } fsm;

    logic [  (AXIS_DATA_WIDTH-1):0] s_axis_tdata;
    logic                           s_axis_tlast;
    logic                           s_axis_tvalid;
    logic                           s_axis_tready;

    fsm current_state = IDLE_ST;

    logic [           7:0] write_cmd_iic_addr;
    logic [SIZE_WIDTH-1:0] write_cmd_size    ;
    logic                  write_cmd_valid   ;


    logic [(AXIS_DATA_WIDTH-1):0] s_axis_tdata_bridge ;
    logic                         s_axis_tlast_bridge ;
    logic                         s_axis_tvalid_bridge;
    logic                         s_axis_tready_bridge;

    logic [           7:0] write_cmd_iic_addr_bridge;
    logic [SIZE_WIDTH-1:0] write_cmd_size_bridge    ;
    logic                  write_cmd_valid_bridge   ;


    logic [(AXIS_DATA_WIDTH-1):0] s_axis_tdata_ucode ;
    logic                         s_axis_tlast_ucode ;
    logic                         s_axis_tvalid_ucode;
    logic                         s_axis_tready_ucode;

    logic [           7:0] write_cmd_iic_addr_ucode;
    logic [SIZE_WIDTH-1:0] write_cmd_size_ucode    ;
    logic                  write_cmd_valid_ucode   ;

    logic [(AXI_DATA_WIDTH-1):0] axi_fifo_dout_data;
    logic                        axi_fifo_dout_last;
    logic                        axi_fifo_rden     ;
    logic                        axi_fifo_empty    ;

    logic [7:0] word_counter;
    logic [1:0] byte_counter;

    logic [7:0] segment_address;

    always_ff @(posedge i_clk, negedge i_resetn) begin : current_state_processing 
        if (~i_resetn) begin 
            current_state <= IDLE_ST;
        end else begin 

            case (current_state)
                IDLE_ST : 
                    if (i_cfg_update_screen) begin 
                        current_state <= ESTABLISH_ADDRESS_ST;
                    end else begin 
                        current_state <= current_state;
                    end 

                ESTABLISH_ADDRESS_ST : 
                    if (o_m_axi_arvalid & i_m_axi_arready) begin 
                        current_state <= AWAIT_DATA_ST;
                    end else begin 
                        current_state <= current_state;
                    end 

                AWAIT_DATA_ST : 
                    if (!axi_fifo_empty) begin 
                        current_state <= TX_CMD_SET_SEGMENT_ADDRESS_ST;
                    end else begin 
                        current_state <= current_state;
                    end 

                TX_CMD_SET_SEGMENT_ADDRESS_ST : 
                    if (s_axis_tready) begin 
                        if (word_counter == 1) begin 
                            current_state <= TX_CMD_SET_DATA_ST;
                        end else begin 
                            current_state <= current_state;
                        end 
                    end else begin 
                        current_state <= current_state;
                    end 

                TX_CMD_SET_DATA_ST : 
                    if (s_axis_tready) begin 
                        current_state <= TX_DATA_ST;
                    end else begin 
                        current_state <= current_state;
                    end 

                TX_DATA_ST : 
                    if (s_axis_tready) begin 
                        if (word_counter == 127) begin 
                            if (byte_counter == 3) begin 
                                current_state <= CHECK_SEGMENT_ADDRESS_ST;
                            end else begin 
                                current_state <= current_state;
                            end 
                        end else begin 
                            current_state <= current_state;
                        end 
                    end else begin 
                        current_state <= current_state;
                    end 
                    
                CHECK_SEGMENT_ADDRESS_ST :
                    if (s_axis_tready) begin 
                        if (segment_address == 8'hb7) begin 
                            current_state <= IDLE_ST;
                        end else begin 
                            current_state <= TX_CMD_SET_SEGMENT_ADDRESS_ST;
                        end 
                    end else begin 
                        current_state <= current_state;
                    end 

                default : 
                    current_state <= current_state;

            endcase
        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : word_counter_processing 
        if (~i_resetn) begin 
            word_counter <= '{default:0};
        end else begin 

            case (current_state)
                TX_CMD_SET_SEGMENT_ADDRESS_ST : 
                    if (s_axis_tready) begin 
                        if (word_counter == 1) begin 
                            word_counter <= '{default:0};
                        end else begin 
                            word_counter <= word_counter + 1;
                        end 
                    end else begin 
                        word_counter <= word_counter;
                    end 

                TX_DATA_ST : 
                    if (s_axis_tready) begin 
                        word_counter <= word_counter + 1;
                    end else begin 
                        word_counter <= word_counter;
                    end 

                default : 
                    word_counter <= '{default:0};
            endcase // current_state
        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : byte_counter_processing 
        if (~i_resetn) begin 
            byte_counter <= '{default:0};
        end else begin 
            case (current_state)
                TX_DATA_ST : 
                    if (s_axis_tready) begin 
                        byte_counter <= byte_counter + 1;
                    end else begin 
                        byte_counter <= byte_counter;
                    end 

                default : 
                    byte_counter <= '{default:0};
            endcase // current_state
        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : o_m_axi_araddr_processing 
        if (~i_resetn) begin 
            o_m_axi_araddr <= '{default:0};
        end else begin 
            case (current_state)
                IDLE_ST : 
                    o_m_axi_araddr <= i_cfg_axi_baseaddress;

                default : 
                    o_m_axi_araddr <= o_m_axi_araddr;

            endcase
        end
    end 


    always_comb o_m_axi_arsize = 3'b010;
    always_comb o_m_axi_arlen  = 8'hFF;
    always_comb o_m_axi_arburst = 2'b01;


    always_ff @(posedge i_clk, negedge i_resetn) begin 
        if (~i_resetn) begin 
            o_m_axi_arvalid <= 1'b0;
        end else begin 

            case (current_state)
                IDLE_ST : 
                    o_m_axi_arvalid <= 1'b0;

                ESTABLISH_ADDRESS_ST : 
                    if (i_m_axi_arready & o_m_axi_arvalid) begin 
                        o_m_axi_arvalid <= 1'b0;
                    end else begin 
                        o_m_axi_arvalid <= 1'b1;
                    end 

                default : 
                    o_m_axi_arvalid <= 1'b0;

            endcase
        end 
    end 



    mp_xpm_fifo_in_sync #(
        .MEMTYPE    ("block"       ),
        .DEPTH      (256           ),
        //
        .TDATA_WIDTH(AXI_DATA_WIDTH),
        .TID_WIDTH  (0             ),
        .TDEST_WIDTH(0             ),
        .TUSER_WIDTH(0             ),
        //
        .HAS_TSTRB  (1'b0          ),
        .HAS_TKEEP  (1'b0          ),
        .HAS_TLAST  (1'b1          )
    ) mp_xpm_fifo_in_sync_inst (
        .i_clk          (i_clk             ),
        .i_reset        (~i_resetn         ),
        //
        .i_s_axis_tdata (i_m_axi_rdata     ),
        .i_s_axis_tstrb (                  ),
        .i_s_axis_tkeep (                  ),
        .i_s_axis_tid   (                  ),
        .i_s_axis_tdest (                  ),
        .i_s_axis_tuser (                  ),
        .i_s_axis_tlast (i_m_axi_rlast     ),
        .i_s_axis_tvalid(i_m_axi_rvalid    ),
        .o_s_axis_tready(o_m_axi_rready    ),
        //
        .o_dout_data    (axi_fifo_dout_data),
        .o_dout_strb    (                  ),
        .o_dout_keep    (                  ),
        .o_dout_id      (                  ),
        .o_dout_dest    (                  ),
        .o_dout_user    (                  ),
        .o_dout_last    (axi_fifo_dout_last),
        .i_rden         (axi_fifo_rden     ),
        .o_empty        (axi_fifo_empty    ));


    always_comb axi_fifo_rden = s_axis_tready & (byte_counter == 3);


    always_ff @(posedge i_clk, negedge i_resetn) begin : s_axis_tdata_processing 
        if (~i_resetn) begin 
            s_axis_tdata <= '{default:0};
        end else begin 
            case (current_state)

                TX_CMD_SET_SEGMENT_ADDRESS_ST : 
                    if (s_axis_tready) begin 
                        case (word_counter)
                            0 : s_axis_tdata <= 8'h00;
                            1 : s_axis_tdata <= segment_address;
                            default : s_axis_tdata <= s_axis_tdata;
                        endcase // word_counter
                    end else begin 
                        s_axis_tdata <= s_axis_tdata;
                    end     

                TX_CMD_SET_DATA_ST : 
                    if (s_axis_tready) begin 
                        s_axis_tdata <= 8'h40;
                    end else begin  
                        s_axis_tdata <= s_axis_tdata;
                    end 

                TX_DATA_ST :
                    if (s_axis_tready) begin
                        case (byte_counter)
                            2'b00 : s_axis_tdata <= axi_fifo_dout_data[ 7: 0];
                            2'b01 : s_axis_tdata <= axi_fifo_dout_data[15: 8];
                            2'b10 : s_axis_tdata <= axi_fifo_dout_data[23:16];
                            2'b11 : s_axis_tdata <= axi_fifo_dout_data[31:24];
                            default : s_axis_tdata <= s_axis_tdata;
                        endcase // byte_counter
                    end else begin
                        s_axis_tdata <= s_axis_tdata;
                    end 

                default : 
                    s_axis_tdata <= s_axis_tdata;

            endcase 
        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : s_axis_tlast_processing
        if (~i_resetn) begin 
            s_axis_tlast <= 1'b0;
        end else begin  
            case (current_state)
                TX_CMD_SET_SEGMENT_ADDRESS_ST: 
                    if (s_axis_tready)
                        case (word_counter)
                            1 : s_axis_tlast <= 1'b1;
                            default : s_axis_tlast <= 1'b0;
                        endcase // word_counter

                TX_CMD_SET_DATA_ST : 
                    if (s_axis_tready) begin 
                        s_axis_tlast <= 1'b0;
                    end else begin 
                        s_axis_tlast <= s_axis_tlast;
                    end 

                TX_DATA_ST : 
                    if (s_axis_tready) begin 
                        if (word_counter == 127) begin 
                            s_axis_tlast <= 1'b1;
                        end else begin 
                            s_axis_tlast <= 1'b0;
                        end 
                    end else begin 
                        s_axis_tlast <= s_axis_tlast;
                    end 

                CHECK_SEGMENT_ADDRESS_ST : 
                    if (s_axis_tready) begin 
                        s_axis_tlast <= 1'b0;
                    end else begin 
                        s_axis_tlast <= s_axis_tlast;
                    end 

                default : 
                    s_axis_tlast <= s_axis_tlast;

            endcase // current_state
        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : s_axis_tvalid_processing 
        if (~i_resetn) begin 
            s_axis_tvalid <= 1'b0;
        end else begin 
            case (current_state)
                TX_CMD_SET_SEGMENT_ADDRESS_ST : 
                    if (s_axis_tready) begin 
                        s_axis_tvalid <= 1'b1;
                    end else begin 
                        s_axis_tvalid <= s_axis_tvalid;
                    end 

                TX_CMD_SET_DATA_ST: 
                    s_axis_tvalid <= 1'b1;

                TX_DATA_ST : 
                    s_axis_tvalid <= 1'b1;

                CHECK_SEGMENT_ADDRESS_ST : 
                    if (s_axis_tready) begin 
                        s_axis_tvalid <= 1'b0;
                    end else begin 
                        s_axis_tvalid <= s_axis_tvalid;
                    end 

                STUB_ST : 
                    if (s_axis_tready) begin 
                        s_axis_tvalid <= 1'b0;
                    end else begin 
                        s_axis_tvalid <= s_axis_tvalid;
                    end 

                default : 
                    s_axis_tvalid <= 1'b0;

            endcase // current_state
        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : write_cmd_iic_addr_processing 
        if (~i_resetn) begin 
            write_cmd_iic_addr <= '{default:0};
        end else begin 
            case (current_state)
                IDLE_ST : 
                    write_cmd_iic_addr <= i_cfg_iic_address;

                default : 
                    write_cmd_iic_addr <= write_cmd_iic_addr;

            endcase // current_state
        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : write_cmd_size_processing 
        if (~i_resetn) begin 
            write_cmd_size <= '{default:0};
        end else begin 
            case (current_state)
                TX_CMD_SET_SEGMENT_ADDRESS_ST : 
                    if (s_axis_tready) begin 
                        if (word_counter == 1) begin 
                            write_cmd_size <= 8'h02;
                        end else begin 
                            write_cmd_size <= write_cmd_size;
                        end 
                    end else begin 
                        write_cmd_size <= write_cmd_size;
                    end 

                TX_CMD_SET_DATA_ST : 
                    if (s_axis_tready) begin 
                        write_cmd_size <= 8'h81;
                    end else begin 
                        write_cmd_size <= write_cmd_size;
                    end 

                default : 
                    write_cmd_size <= write_cmd_size;
            endcase // current_state_processing
        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : write_cmd_valid_processing 
        if (~i_resetn) begin 
            write_cmd_valid <= 1'b0;
        end else begin 
            case (current_state)
                TX_CMD_SET_SEGMENT_ADDRESS_ST : 
                    if (s_axis_tready) begin 
                        if (word_counter == 1) begin 
                            write_cmd_valid <= 1'b1;
                        end else begin 
                            write_cmd_valid <= 1'b0;
                        end 
                    end else begin 
                        write_cmd_valid <= 1'b0;
                    end 

                TX_CMD_SET_DATA_ST : 
                    if (s_axis_tready) begin 
                        write_cmd_valid <= 1'b1;
                    end else begin 
                        write_cmd_valid <= 1'b0;
                    end 

                default : 
                    write_cmd_valid <= 1'b0;
            endcase // current_state
        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : segment_address_processing 
        if (~i_resetn) begin 
            segment_address <= 8'hb0;
        end else begin 
            case (current_state)

                IDLE_ST : 
                    segment_address <= 8'hb0;
                
                CHECK_SEGMENT_ADDRESS_ST :
                    if (s_axis_tready) begin 
                        segment_address <= segment_address + 1;
                    end else begin 
                        segment_address <= segment_address;
                    end         

                default : 
                    segment_address <= segment_address;
            endcase // current_state
        end 
    end 



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




    axi_ssd1306_ucode_processor #(
        .S_AXI_ID_WIDTH  (S_AXI_UCODE_ID_WIDTH  ),
        .S_AXI_DATA_WIDTH(S_AXI_UCODE_DATA_WIDTH),
        .S_AXI_ADDR_WIDTH(S_AXI_UCODE_ADDR_WIDTH),
        .SIZE_WIDTH      (SIZE_WIDTH            ),
        .DATA_WIDTH      (AXIS_DATA_WIDTH       )
    ) axi_ssd1306_ucode_processor_inst (
        .i_clk               (i_clk                   ),
        .i_resetn            (i_resetn                ),
        .i_cfg_initialize    (i_cfg_initialize        ),
        .i_cfg_iic_address   (i_cfg_iic_address       ),
        ///
        .o_write_cmd_iic_addr(write_cmd_iic_addr_ucode),
        .o_write_cmd_size    (write_cmd_size_ucode    ),
        .o_write_cmd_valid   (write_cmd_valid_ucode   ),
        //
        .o_s_axis_tdata      (s_axis_tdata_ucode      ),
        .o_s_axis_tlast      (s_axis_tlast_ucode      ),
        .o_s_axis_tvalid     (s_axis_tvalid_ucode     ),
        .i_s_axis_tready     (s_axis_tready_ucode     ),
        // Configuration loading bus
        .S_AXI_ACLK          (S_AXI_UCODE_ACLK        ),
        .S_AXI_ARESETN       (S_AXI_UCODE_ARESETN     ),
        .S_AXI_AWID          (S_AXI_UCODE_AWID        ),
        .S_AXI_AWADDR        (S_AXI_UCODE_AWADDR      ),
        .S_AXI_AWLEN         (S_AXI_UCODE_AWLEN       ),
        .S_AXI_AWSIZE        (S_AXI_UCODE_AWSIZE      ),
        .S_AXI_AWBURST       (S_AXI_UCODE_AWBURST     ),
        .S_AXI_AWLOCK        (S_AXI_UCODE_AWLOCK      ),
        .S_AXI_AWCACHE       (S_AXI_UCODE_AWCACHE     ),
        .S_AXI_AWPROT        (S_AXI_UCODE_AWPROT      ),
        .S_AXI_AWQOS         (S_AXI_UCODE_AWQOS       ),
        .S_AXI_AWREGION      (S_AXI_UCODE_AWREGION    ),
        .S_AXI_AWVALID       (S_AXI_UCODE_AWVALID     ),
        .S_AXI_AWREADY       (S_AXI_UCODE_AWREADY     ),
        .S_AXI_WDATA         (S_AXI_UCODE_WDATA       ),
        .S_AXI_WSTRB         (S_AXI_UCODE_WSTRB       ),
        .S_AXI_WLAST         (S_AXI_UCODE_WLAST       ),
        .S_AXI_WVALID        (S_AXI_UCODE_WVALID      ),
        .S_AXI_WREADY        (S_AXI_UCODE_WREADY      ),
        .S_AXI_BID           (S_AXI_UCODE_BID         ),
        .S_AXI_BRESP         (S_AXI_UCODE_BRESP       ),
        .S_AXI_BVALID        (S_AXI_UCODE_BVALID      ),
        .S_AXI_BREADY        (S_AXI_UCODE_BREADY      ),
        .S_AXI_ARID          (S_AXI_UCODE_ARID        ),
        .S_AXI_ARADDR        (S_AXI_UCODE_ARADDR      ),
        .S_AXI_ARLEN         (S_AXI_UCODE_ARLEN       ),
        .S_AXI_ARSIZE        (S_AXI_UCODE_ARSIZE      ),
        .S_AXI_ARBURST       (S_AXI_UCODE_ARBURST     ),
        .S_AXI_ARLOCK        (S_AXI_UCODE_ARLOCK      ),
        .S_AXI_ARCACHE       (S_AXI_UCODE_ARCACHE     ),
        .S_AXI_ARPROT        (S_AXI_UCODE_ARPROT      ),
        .S_AXI_ARQOS         (S_AXI_UCODE_ARQOS       ),
        .S_AXI_ARREGION      (S_AXI_UCODE_ARREGION    ),
        .S_AXI_ARVALID       (S_AXI_UCODE_ARVALID     ),
        .S_AXI_ARREADY       (S_AXI_UCODE_ARREADY     ),
        .S_AXI_RID           (S_AXI_UCODE_RID         ),
        .S_AXI_RDATA         (S_AXI_UCODE_RDATA       ),
        .S_AXI_RRESP         (S_AXI_UCODE_RRESP       ),
        .S_AXI_RLAST         (S_AXI_UCODE_RLAST       ),
        .S_AXI_RVALID        (S_AXI_UCODE_RVALID      ),
        .S_AXI_RREADY        (S_AXI_UCODE_RREADY      )
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
        .i_s_axis_tdata_0      (s_axis_tdata_ucode       ),
        .i_s_axis_tlast_0      (s_axis_tlast_ucode       ),
        .i_s_axis_tvalid_0     (s_axis_tvalid_ucode      ),
        .o_s_axis_tready_0     (s_axis_tready_ucode      ),
        // data channel 1 : from internal logic
        .i_write_cmd_iic_addr_1(write_cmd_iic_addr       ),
        .i_write_cmd_size_1    (write_cmd_size           ),
        .i_write_cmd_valid_1   (write_cmd_valid          ),
        //
        .i_s_axis_tdata_1      (s_axis_tdata             ),
        .i_s_axis_tlast_1      (s_axis_tlast             ),
        .i_s_axis_tvalid_1     (s_axis_tvalid            ),
        .o_s_axis_tready_1     (s_axis_tready            ),
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



    // ila_axis ila_axis_inst (
    //     .clk   (i_clk             ),   // input wire clk
    //     .probe0(write_cmd_iic_addr),   // input wire [7:0]  probe0
    //     .probe1(write_cmd_size    ),   // input wire [7:0]  probe1
    //     .probe2(write_cmd_valid   ),   // input wire [0:0]  probe2
    //     .probe3(s_axis_tdata      ),   // input wire [31:0]  probe3
    //     .probe4(s_axis_tlast      ),   // input wire [0:0]  probe4
    //     .probe5(s_axis_tvalid     ),   // input wire [0:0]  probe5
    //     .probe6(s_axis_tready     )    // input wire [0:0]  probe6
    // );


endmodule