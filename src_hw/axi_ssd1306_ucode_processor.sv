
`timescale 1 ns / 1 ps

module axi_ssd1306_ucode_processor #(
    parameter integer C_S_AXI_ID_WIDTH     = 0 ,
    parameter integer C_S_AXI_DATA_WIDTH   = 32,
    parameter integer C_S_AXI_ADDR_WIDTH   = 8 ,
    parameter integer C_S_AXI_AWUSER_WIDTH = 0 ,
    parameter integer C_S_AXI_ARUSER_WIDTH = 0 ,
    parameter integer C_S_AXI_WUSER_WIDTH  = 0 ,
    parameter integer C_S_AXI_RUSER_WIDTH  = 0 ,
    parameter integer C_S_AXI_BUSER_WIDTH  = 0
) (
    input  logic                              S_AXI_ACLK    ,
    input  logic                              S_AXI_ARESETN ,
    input  logic [      C_S_AXI_ID_WIDTH-1:0] S_AXI_AWID    ,
    input  logic [    C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR  ,
    input  logic [                       7:0] S_AXI_AWLEN   ,
    input  logic [                       2:0] S_AXI_AWSIZE  ,
    input  logic [                       1:0] S_AXI_AWBURST ,
    input  logic                              S_AXI_AWLOCK  ,
    input  logic [                       3:0] S_AXI_AWCACHE ,
    input  logic [                       2:0] S_AXI_AWPROT  ,
    input  logic [                       3:0] S_AXI_AWQOS   ,
    input  logic [                       3:0] S_AXI_AWREGION,
    input  logic [  C_S_AXI_AWUSER_WIDTH-1:0] S_AXI_AWUSER  ,
    input  logic                              S_AXI_AWVALID ,
    output logic                              S_AXI_AWREADY ,
    input  logic [    C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA   ,
    input  logic [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB   ,
    input  logic                              S_AXI_WLAST   ,
    input  logic [   C_S_AXI_WUSER_WIDTH-1:0] S_AXI_WUSER   ,
    input  logic                              S_AXI_WVALID  ,
    output logic                              S_AXI_WREADY  ,
    output logic [      C_S_AXI_ID_WIDTH-1:0] S_AXI_BID     ,
    output logic [                       1:0] S_AXI_BRESP   ,
    output logic [   C_S_AXI_BUSER_WIDTH-1:0] S_AXI_BUSER   ,
    output logic                              S_AXI_BVALID  ,
    input  logic                              S_AXI_BREADY  ,
    input  logic [      C_S_AXI_ID_WIDTH-1:0] S_AXI_ARID    ,
    input  logic [    C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR  ,
    input  logic [                       7:0] S_AXI_ARLEN   ,
    input  logic [                       2:0] S_AXI_ARSIZE  ,
    input  logic [                       1:0] S_AXI_ARBURST ,
    input  logic                              S_AXI_ARLOCK  ,
    input  logic [                       3:0] S_AXI_ARCACHE ,
    input  logic [                       2:0] S_AXI_ARPROT  ,
    input  logic [                       3:0] S_AXI_ARQOS   ,
    input  logic [                       3:0] S_AXI_ARREGION,
    input  logic [  C_S_AXI_ARUSER_WIDTH-1:0] S_AXI_ARUSER  ,
    input  logic                              S_AXI_ARVALID ,
    output logic                              S_AXI_ARREADY ,
    output logic [      C_S_AXI_ID_WIDTH-1:0] S_AXI_RID     ,
    output logic [    C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA   ,
    output logic [                       1:0] S_AXI_RRESP   ,
    output logic                              S_AXI_RLAST   ,
    output logic [   C_S_AXI_RUSER_WIDTH-1:0] S_AXI_RUSER   ,
    output logic                              S_AXI_RVALID  ,
    input  logic                              S_AXI_RREADY
);

    typedef enum{
        RST_ST  , 
        CHK_AW_ST,
        WRITE_AXI_ST, 
        RESP_AXI_ST,

        CHK_AR_ST,
        READ_AXI_ST,

        STUB_ST 
    } fsm;

    fsm current_state = RST_ST;

    logic s_axi_awready_reg = 1'b0;
    logic s_axi_arready_reg = 1'b0;

    logic [C_S_AXI_ADDR_WIDTH-1:0] axi_addr;

    logic [7:0] axi_axlen_counter;

    logic s_axi_wready_reg = 1'b0;

    logic s_axi_bvalid_reg = 1'b0;

    logic s_axi_rvalid_reg = 1'b0;

    logic s_axi_rlast_reg = 1'b0;

    logic [C_S_AXI_ID_WIDTH-1:0] s_axi_rid_reg;

    logic [C_S_AXI_ID_WIDTH-1:0] s_axi_bid_reg;

    logic [ 5:0] addra;
    logic [ 5:0] addrb = '{default:0};

    logic [31:0] douta;
    logic [31:0] doutb;

    logic [31:0] dina;
    logic [31:0] dinb = '{default:0};

    logic [ 3:0] wea;
    logic [ 3:0] web = '{default:0};

    logic ena;
    logic enb;



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
                    if (S_AXI_WVALID & s_axi_wready_reg & S_AXI_WLAST) begin 
                        current_state <= RESP_AXI_ST;
                    end else begin 
                        current_state <= current_state;
                    end 

                RESP_AXI_ST : 
                    if (S_AXI_BREADY & s_axi_bvalid_reg) begin 
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
                    if (s_axi_rvalid_reg & S_AXI_RREADY & s_axi_rlast_reg) begin 
                        current_state <= CHK_AW_ST;
                    end else begin 
                        current_state <= current_state;
                    end  

                default : 
                    current_state <= current_state;

            endcase // current_state
        end 
    end 


    always_comb S_AXI_AWREADY = s_axi_awready_reg;
    always_comb S_AXI_ARREADY = s_axi_arready_reg;
    always_comb S_AXI_WREADY = s_axi_wready_reg;
    always_comb S_AXI_BVALID = s_axi_bvalid_reg;
    always_comb S_AXI_RVALID = s_axi_rvalid_reg;
    always_comb S_AXI_RDATA = douta;
    always_comb S_AXI_RLAST = s_axi_rlast_reg;
    always_comb S_AXI_RID = s_axi_rid_reg;
    always_comb S_AXI_BID = s_axi_bid_reg;

    always_ff @(posedge S_AXI_ACLK) begin : axi_addr_processing 
        case (current_state)
            CHK_AW_ST : 
                axi_addr <= S_AXI_AWADDR;

            CHK_AR_ST : 
                axi_addr <= S_AXI_ARADDR;

            WRITE_AXI_ST : 
                if (S_AXI_WVALID & s_axi_wready_reg) begin 
                    axi_addr <= axi_addr + 4;
                end else begin 
                    axi_addr <= axi_addr;
                end 

            READ_AXI_ST : 
                if (S_AXI_RREADY) begin 
                    axi_addr <= axi_addr + 4;
                end else begin 
                    axi_addr <= axi_addr;
                end 

            default : 
                axi_addr <= 'bz;
        endcase // current_state
    end 


    always_ff @(posedge S_AXI_ACLK) begin : axi_axlen_counter_processing 
        case (current_state) 
            CHK_AW_ST : 
                axi_axlen_counter <= S_AXI_AWLEN;

            WRITE_AXI_ST : 
                if (S_AXI_WVALID & s_axi_wready_reg) begin 
                    axi_axlen_counter <= axi_axlen_counter - 1;
                end else begin 
                    axi_axlen_counter <= axi_axlen_counter;
                end 

            CHK_AR_ST : 
                axi_axlen_counter <= S_AXI_ARLEN;

            READ_AXI_ST : 
                if (S_AXI_RREADY & s_axi_rvalid_reg) begin 
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

 
    always_ff @(posedge S_AXI_ACLK) begin : s_axi_awready_reg_processing 
        case (current_state)
            CHK_AW_ST : 
                if (S_AXI_AWVALID) begin 
                    s_axi_awready_reg <= 1'b1;
                end else begin 
                    s_axi_awready_reg <= 1'b0;
                end 

            default : 
                s_axi_awready_reg <= 1'b0;

        endcase // current_state
    end 


    always_ff @(posedge S_AXI_ACLK) begin : s_axi_wready_reg_processing 
        case (current_state)
            WRITE_AXI_ST : 
                if (S_AXI_WVALID & s_axi_wready_reg & S_AXI_WLAST) begin 
                    s_axi_wready_reg <= 1'b0;
                end else begin 
                    s_axi_wready_reg <= 1'b1;
                end 

            default : 
                s_axi_wready_reg <= 1'b0;

        endcase // current_state
    end 


    always_ff @(posedge S_AXI_ACLK) begin : s_axi_bvalid_reg_processing 
        case (current_state)
            RESP_AXI_ST : 
                if (S_AXI_BREADY & s_axi_bvalid_reg) begin 
                    s_axi_bvalid_reg <= 1'b0;
                end else begin 
                    s_axi_bvalid_reg <= 1'b1;
                end 

            default : 
                s_axi_bvalid_reg <= 1'b0;
        endcase // current_state
    end 

    always_ff @(posedge S_AXI_ACLK) begin : s_axi_bid_reg_processing 
        case (current_state) 

            CHK_AW_ST : 
                s_axi_bid_reg <= S_AXI_AWID;

            default : 
                s_axi_bid_reg <= s_axi_bid_reg;
        endcase // current_state
    end 

/////////////////////////////////////////////////////////////
///////////////////// -= READ DOMAIN =- /////////////////////
/////////////////////////////////////////////////////////////

    always_ff @(posedge S_AXI_ACLK) begin : s_axi_arready_reg_processing 
        case (current_state)
            CHK_AR_ST : 
                if (S_AXI_ARVALID) begin 
                    s_axi_arready_reg <= 1'b1;
                end else begin 
                    s_axi_arready_reg <= 1'b0;
                end 

            default : 
                s_axi_arready_reg <= 1'b0;

        endcase // current_state
    end 


    always_ff @(posedge S_AXI_ACLK) begin : s_axi_rvalid_reg_processing 
        case (current_state)
            READ_AXI_ST :
                if (S_AXI_RREADY & s_axi_rlast_reg & s_axi_rvalid_reg) begin 
                    s_axi_rvalid_reg <= 1'b0;
                end else begin 
                    s_axi_rvalid_reg <= 1'b1;
                end 

            default : 
                s_axi_rvalid_reg <= 1'b0;

        endcase // current_state
    end 


    always_comb s_axi_rlast_reg = (axi_axlen_counter == 0);


    always_ff @(posedge S_AXI_ACLK) begin : s_axi_rid_reg_processing 
        case (current_state)
            CHK_AR_ST : 
                s_axi_rid_reg <= S_AXI_ARID;

            default : 
                s_axi_rid_reg <= s_axi_rid_reg;

        endcase // current_state
    end 


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


endmodule

