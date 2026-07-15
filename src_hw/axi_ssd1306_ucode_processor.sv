
`timescale 1 ns / 1 ps

module axi_ssd1306_ucode_processor #(
    parameter integer S_AXI_ID_WIDTH   = 0 ,
    parameter integer S_AXI_DATA_WIDTH = 32,
    parameter integer S_AXI_ADDR_WIDTH = 8 ,
    parameter integer SIZE_WIDTH       = 16,
    parameter integer DATA_WIDTH       = 32
) (
    input  logic                            i_clk             ,
    input  logic                            i_resetn          ,
    //
    input  logic                            i_cfg_initialize  ,
    input  logic [                     7:0] i_cfg_iic_address ,
    ///
    output logic [                     7:0] WRITE_CMD_IIC_ADDR,
    output logic [          SIZE_WIDTH-1:0] WRITE_CMD_SIZE    ,
    output logic                            WRITE_CMD_VALID   ,
    //
    output logic [          DATA_WIDTH-1:0] M_AXIS_TDATA      ,
    output logic                            M_AXIS_TLAST      ,
    output logic                            M_AXIS_TVALID     ,
    input  logic                            M_AXIS_TREADY     ,
    // Configuration loading bus
    input  logic                            S_AXI_ACLK        ,
    input  logic                            S_AXI_ARESETN     ,
    input  logic [      S_AXI_ID_WIDTH-1:0] S_AXI_AWID        ,
    input  logic [    S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR      ,
    input  logic [                     7:0] S_AXI_AWLEN       ,
    input  logic [                     2:0] S_AXI_AWSIZE      ,
    input  logic [                     1:0] S_AXI_AWBURST     ,
    input  logic                            S_AXI_AWLOCK      ,
    input  logic [                     3:0] S_AXI_AWCACHE     ,
    input  logic [                     2:0] S_AXI_AWPROT      ,
    input  logic [                     3:0] S_AXI_AWQOS       ,
    input  logic [                     3:0] S_AXI_AWREGION    ,
    input  logic                            S_AXI_AWVALID     ,
    output logic                            S_AXI_AWREADY     ,
    input  logic [    S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA       ,
    input  logic [(S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB       ,
    input  logic                            S_AXI_WLAST       ,
    input  logic                            S_AXI_WVALID      ,
    output logic                            S_AXI_WREADY      ,
    output logic [      S_AXI_ID_WIDTH-1:0] S_AXI_BID         ,
    output logic [                     1:0] S_AXI_BRESP       ,
    output logic                            S_AXI_BVALID      ,
    input  logic                            S_AXI_BREADY      ,
    input  logic [      S_AXI_ID_WIDTH-1:0] S_AXI_ARID        ,
    input  logic [    S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR      ,
    input  logic [                     7:0] S_AXI_ARLEN       ,
    input  logic [                     2:0] S_AXI_ARSIZE      ,
    input  logic [                     1:0] S_AXI_ARBURST     ,
    input  logic                            S_AXI_ARLOCK      ,
    input  logic [                     3:0] S_AXI_ARCACHE     ,
    input  logic [                     2:0] S_AXI_ARPROT      ,
    input  logic [                     3:0] S_AXI_ARQOS       ,
    input  logic [                     3:0] S_AXI_ARREGION    ,
    input  logic                            S_AXI_ARVALID     ,
    output logic                            S_AXI_ARREADY     ,
    output logic [      S_AXI_ID_WIDTH-1:0] S_AXI_RID         ,
    output logic [    S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA       ,
    output logic [                     1:0] S_AXI_RRESP       ,
    output logic                            S_AXI_RLAST       ,
    output logic                            S_AXI_RVALID      ,
    input  logic                            S_AXI_RREADY
);



    localparam integer ADDR_LSB          = (S_AXI_DATA_WIDTH/32) + 1;
    localparam integer OPT_MEM_ADDR_BITS = 5                        ;

    typedef enum{
        RST_ST  , 

        CHK_AW_ST,
        WRITE_AXI_ST, 
        RESP_AXI_ST,

        CHK_AR_ST,
        READ_AXI_ST

    } fsm;

    fsm current_state = RST_ST;

    logic [S_AXI_ADDR_WIDTH-1:0] axi_addr         ;
    logic [                 1:0] axi_axburst      ;
    logic [                 7:0] axi_axlen_counter;
    logic [                 7:0] axi_axlen        ;

    logic [31:0] aw_wrap_size;
    logic [31:0] ar_wrap_size;
    logic        aw_wrap_en  ;
    logic        ar_wrap_en  ;

    logic [OPT_MEM_ADDR_BITS:0] addra;
    logic [OPT_MEM_ADDR_BITS:0] addrb;

    logic [31:0] douta;
    logic [31:0] doutb;

    logic [31:0] dina;
    logic [31:0] dinb = '{default:0};

    logic [ 3:0] wea;
    logic [ 3:0] web = '{default:0};

    logic ena;
    logic enb;

    always_comb aw_wrap_size  = (S_AXI_DATA_WIDTH/8 * (axi_axlen));
    always_comb ar_wrap_size  = (S_AXI_DATA_WIDTH/8 * (axi_axlen));

    always_comb aw_wrap_en    = ((axi_addr & aw_wrap_size) == aw_wrap_size)? 1'b1: 1'b0;
    always_comb ar_wrap_en    = ((axi_addr & ar_wrap_size) == ar_wrap_size)? 1'b1: 1'b0;


    always_comb S_AXI_RDATA = douta;


    always_ff @(posedge S_AXI_ACLK) begin 
        if (~S_AXI_ARESETN) begin 
            current_state <= RST_ST;
        end else begin 

            case (current_state)
                RST_ST :    
                    current_state <= CHK_AW_ST;

                CHK_AW_ST : 
                    if (S_AXI_AWVALID) begin 
                        current_state <= WRITE_AXI_ST;
                    end else begin 
                        current_state <= CHK_AR_ST; 
                    end 

                WRITE_AXI_ST : 
                    if (S_AXI_WVALID & S_AXI_WREADY & S_AXI_WLAST) begin 
                        current_state <= RESP_AXI_ST;
                    end else begin 
                        current_state <= current_state;
                    end 

                RESP_AXI_ST : 
                    if (S_AXI_BREADY & S_AXI_BVALID) begin 
                        current_state <= CHK_AR_ST;
                    end else begin 
                        current_state <= current_state;
                    end 

                CHK_AR_ST : 
                    if (S_AXI_ARVALID) begin 
                        current_state <= READ_AXI_ST;
                    end else begin 
                        current_state <= CHK_AW_ST;
                    end 

                READ_AXI_ST : 
                    if (S_AXI_RVALID & S_AXI_RREADY & S_AXI_RLAST) begin 
                        current_state <= CHK_AW_ST;
                    end else begin 
                        current_state <= current_state;
                    end  

                default : 
                    current_state <= current_state;

            endcase // current_state
        end 
    end 


    always_ff @(posedge S_AXI_ACLK) begin : axi_addr_processing 
        case (current_state)
            CHK_AW_ST : 
                axi_addr <= S_AXI_AWADDR;

            CHK_AR_ST : 
                axi_addr <= S_AXI_ARADDR;

            WRITE_AXI_ST : 
                if (S_AXI_WVALID & S_AXI_WREADY) begin 
                    case (axi_axburst) 
                        2'b00 : begin axi_addr <= axi_addr; end 
                        2'b01 : begin 
                            axi_addr[S_AXI_ADDR_WIDTH-1:ADDR_LSB] <= axi_addr[S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                            axi_addr[ADDR_LSB-1:0]                  <= {ADDR_LSB{1'b0}};
                        end 
                        2'b10 :             
                            if (aw_wrap_en) begin
                                axi_addr <= (axi_addr - aw_wrap_size);
                            end else begin
                                axi_addr[S_AXI_ADDR_WIDTH-1:ADDR_LSB] <= axi_addr[S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                                axi_addr[ADDR_LSB-1:0]                  <= {ADDR_LSB{1'b0}};
                            end

                        default : axi_addr <= axi_addr [S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1; 
                    endcase // axi_axburst
                    // axi_addr <= axi_addr + 4;
                end else begin 
                    axi_addr <= axi_addr;
                end 

            READ_AXI_ST : 
                if (S_AXI_RREADY) begin 
                    case (axi_axburst) 
                        2'b00 : axi_addr <= axi_addr;
                        2'b01 : begin 
                            axi_addr[S_AXI_ADDR_WIDTH-1:ADDR_LSB] <= axi_addr[S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                            axi_addr[ADDR_LSB-1:0]                  <= {ADDR_LSB{1'b0}};
                        end 
                        2'b10 :             
                            if (aw_wrap_en) begin
                                axi_addr <= (axi_addr - aw_wrap_size);
                            end else begin
                                axi_addr[S_AXI_ADDR_WIDTH-1:ADDR_LSB] <= axi_addr[S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                                axi_addr[ADDR_LSB-1:0]                  <= {ADDR_LSB{1'b0}};
                            end

                        default : axi_addr <= axi_addr [S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1; 
                    endcase // axi_axburst
                    // axi_addr <= axi_addr + 4;
                end else begin 
                    axi_addr <= axi_addr;
                end 

            default : 
                axi_addr <= axi_addr;
        endcase // current_state
    end 


    always_ff @(posedge S_AXI_ACLK) begin : axi_axlen_processing 
        case (current_state)
            CHK_AW_ST : 
                axi_axlen <= S_AXI_AWLEN;

            CHK_AR_ST : 
                axi_axlen <= S_AXI_ARLEN;

            default : 
                axi_axlen <= axi_axlen;

        endcase // current_state
    end 


    always_ff @(posedge S_AXI_ACLK) begin : axi_axburst_processing 
        case (current_state)
            CHK_AW_ST : 
                axi_axburst <= S_AXI_AWBURST;
            
            CHK_AR_ST : 
                axi_axburst <= S_AXI_ARBURST;
            
            default : 
                axi_axburst <= axi_axburst;

        endcase
    end 


    always_ff @(posedge S_AXI_ACLK) begin : axi_axlen_counter_processing 
        case (current_state) 
            CHK_AW_ST : 
                axi_axlen_counter <= S_AXI_AWLEN;

            WRITE_AXI_ST : 
                if (S_AXI_WVALID & S_AXI_WREADY) begin 
                    axi_axlen_counter <= axi_axlen_counter - 1;
                end else begin 
                    axi_axlen_counter <= axi_axlen_counter;
                end 

            CHK_AR_ST : 
                axi_axlen_counter <= S_AXI_ARLEN;

            READ_AXI_ST : 
                if (S_AXI_RREADY & S_AXI_RVALID) begin 
                    axi_axlen_counter <= axi_axlen_counter - 1;
                end else begin 
                    axi_axlen_counter <= axi_axlen_counter;
                end 


            default : 
                axi_axlen_counter <= axi_axlen_counter;

        endcase // current_state
    end 

/////////////////////////////////////////////////////////////
///////////////////// -= WRITE DOMAIN =- ////////////////////
/////////////////////////////////////////////////////////////

 
    always_ff @(posedge S_AXI_ACLK) begin : S_AXI_AWREADY_processing 
        case (current_state)
            CHK_AW_ST : 
                if (S_AXI_AWVALID) begin 
                    S_AXI_AWREADY <= 1'b1;
                end else begin 
                    S_AXI_AWREADY <= 1'b0;
                end 

            default : 
                S_AXI_AWREADY <= 1'b0;

        endcase // current_state
    end 


    always_ff @(posedge S_AXI_ACLK) begin : S_AXI_WREADY_processing 
        case (current_state)
            WRITE_AXI_ST : 
                if (S_AXI_WVALID & S_AXI_WREADY & S_AXI_WLAST) begin 
                    S_AXI_WREADY <= 1'b0;
                end else begin 
                    S_AXI_WREADY <= 1'b1;
                end 

            default : 
                S_AXI_WREADY <= 1'b0;

        endcase // current_state
    end 


    always_ff @(posedge S_AXI_ACLK) begin : S_AXI_BVALID_processing 
        case (current_state)
            RESP_AXI_ST : 
                if (S_AXI_BREADY & S_AXI_BVALID) begin 
                    S_AXI_BVALID <= 1'b0;
                end else begin 
                    S_AXI_BVALID <= 1'b1;
                end 

            default : 
                S_AXI_BVALID <= 1'b0;
        endcase // current_state
    end 


    always_ff @(posedge S_AXI_ACLK) begin : S_AXI_BID_processing 
        case (current_state) 

            CHK_AW_ST : 
                S_AXI_BID <= S_AXI_AWID;

            default : 
                S_AXI_BID <= S_AXI_BID;

        endcase // current_state
    end 


    always_comb S_AXI_BRESP = '{default:0};


/////////////////////////////////////////////////////////////
///////////////////// -= READ DOMAIN =- /////////////////////
/////////////////////////////////////////////////////////////


    always_ff @(posedge S_AXI_ACLK) begin : S_AXI_ARREADY_processing 
        case (current_state)
            CHK_AR_ST : 
                if (S_AXI_ARVALID) begin 
                    S_AXI_ARREADY <= 1'b1;
                end else begin 
                    S_AXI_ARREADY <= 1'b0;
                end 

            default : 
                S_AXI_ARREADY <= 1'b0;

        endcase // current_state
    end 


    always_ff @(posedge S_AXI_ACLK) begin : S_AXI_RVALID_processing 
        case (current_state)
            READ_AXI_ST :
                if (S_AXI_RREADY & S_AXI_RLAST & S_AXI_RVALID) begin 
                    S_AXI_RVALID <= 1'b0;
                end else begin 
                    S_AXI_RVALID <= 1'b1;
                end 

            default : 
                S_AXI_RVALID <= 1'b0;

        endcase // current_state
    end 


    always_comb S_AXI_RLAST = (axi_axlen_counter == 0);


    always_ff @(posedge S_AXI_ACLK) begin : s_axi_rid_processing 
        case (current_state)
            CHK_AR_ST : 
                S_AXI_RID <= S_AXI_ARID;

            default : 
                S_AXI_RID <= S_AXI_RID;

        endcase // current_state
    end 


    always_comb S_AXI_RRESP = '{default:0};


/////////////////////////////////////////////////////////////
/////////////////// -= MEMORY INTERFACE =- //////////////////
/////////////////////////////////////////////////////////////


    always_comb addra = axi_addr[7:2];
    always_comb dina = S_AXI_WDATA;

    generate 
        for (genvar index = 0; index < 4; index++) begin : gen_wea
            always_comb wea[index] = S_AXI_WVALID & S_AXI_WSTRB[index];
        end 
    endgenerate

    always_comb ena = (current_state == WRITE_AXI_ST) || (current_state == READ_AXI_ST);

    xpm_memory_tdpram #(
        .ADDR_WIDTH_A           (6              ),
        .ADDR_WIDTH_B           (6              ),
        .AUTO_SLEEP_TIME        (0              ),
        .BYTE_WRITE_WIDTH_A     (8              ),
        .BYTE_WRITE_WIDTH_B     (8              ),
        .CASCADE_HEIGHT         (0              ),
        .CLOCKING_MODE          ("common_clock" ),
        .ECC_BIT_RANGE          ("7:0"          ),
        .ECC_MODE               ("no_ecc"       ),
        .ECC_TYPE               ("none"         ),
        .IGNORE_INIT_SYNTH      (0              ),
        .MEMORY_INIT_FILE       ("none"         ),
        .MEMORY_INIT_PARAM      ("0"            ),
        .MEMORY_OPTIMIZATION    ("true"         ),
        .MEMORY_PRIMITIVE       ("auto"         ),
        .MEMORY_SIZE            (2048           ),
        .MESSAGE_CONTROL        (0              ),
        .RAM_DECOMP             ("auto"         ),
        .READ_DATA_WIDTH_A      (32             ),
        .READ_DATA_WIDTH_B      (32             ),
        .READ_LATENCY_A         (1              ),
        .READ_LATENCY_B         (1              ),
        .READ_RESET_VALUE_A     ("0"            ),
        .READ_RESET_VALUE_B     ("0"            ),
        .RST_MODE_A             ("SYNC"         ),
        .RST_MODE_B             ("SYNC"         ),
        .SIM_ASSERT_CHK         (0              ),
        .USE_EMBEDDED_CONSTRAINT(0              ),
        .USE_MEM_INIT           (1              ),
        .USE_MEM_INIT_MMI       (0              ),
        .WAKEUP_TIME            ("disable_sleep"),
        .WRITE_DATA_WIDTH_A     (32             ),
        .WRITE_DATA_WIDTH_B     (32             ),
        .WRITE_MODE_A           ("no_change"    ),
        .WRITE_MODE_B           ("no_change"    ),
        .WRITE_PROTECT          (1              ) 
    ) xpm_memory_tdpram_inst (
        .dbiterra      (              ),
        .dbiterrb      (              ),
        .douta         (douta         ),
        .doutb         (doutb         ),
        .sbiterra      (              ),
        .sbiterrb      (              ),
        .addra         (addra         ),
        .addrb         (addrb         ),
        .clka          (S_AXI_ACLK    ),
        .clkb          (S_AXI_ACLK    ),
        .dina          (dina          ),
        .dinb          (dinb          ),
        .ena           (ena           ),
        .enb           (enb           ),
        .injectdbiterra(1'b0          ),
        .injectdbiterrb(1'b0          ),
        .injectsbiterra(1'b0          ),
        .injectsbiterrb(1'b0          ),
        .regcea        (1'b1          ),
        .regceb        (1'b1          ),
        .rsta          (~S_AXI_ARESETN),
        .rstb          (~S_AXI_ARESETN),
        .sleep         (1'b0          ),
        .wea           (wea           ),
        .web           (web           )
    );

/////////////////////////////////////////////////////////////
/////////////////// -= UCODE PROCESSOR =- ///////////////////
/////////////////////////////////////////////////////////////


    axis_ucode_processor #(
        .SIZE_WIDTH(SIZE_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) axis_ucode_processor_inst (
        .i_clk             (i_clk             ),
        .i_resetn          (i_resetn          ),
        //
        .i_cfg_initialize  (i_cfg_initialize  ),
        .i_cfg_iic_address (i_cfg_iic_address ),
        //
        .o_addr            (addrb             ),
        .o_en              (enb               ),
        .i_din             (doutb             ),
        //
        .WRITE_CMD_IIC_ADDR(WRITE_CMD_IIC_ADDR),
        .WRITE_CMD_SIZE    (WRITE_CMD_SIZE    ),
        .WRITE_CMD_VALID   (WRITE_CMD_VALID   ),
        //
        .M_AXIS_TDATA      (M_AXIS_TDATA      ),
        .M_AXIS_TLAST      (M_AXIS_TLAST      ),
        .M_AXIS_TVALID     (M_AXIS_TVALID     ),
        .M_AXIS_TREADY     (M_AXIS_TREADY     )
        //
    );

endmodule

