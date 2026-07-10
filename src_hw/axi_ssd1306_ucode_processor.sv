
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



    // AXI4FULL signals
    logic [ C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr ;
    logic                           axi_awready;
    logic                           axi_wready ;
    logic [                    1:0] axi_bresp  ;
    logic [C_S_AXI_BUSER_WIDTH-1:0] axi_buser  ;
    logic                           axi_bvalid ;
    logic [ C_S_AXI_ADDR_WIDTH-1:0] axi_araddr ;
    logic                           axi_arready;
    logic [ C_S_AXI_DATA_WIDTH-1:0] axi_rdata  ;
    logic [                    1:0] axi_rresp  ;
    logic                           axi_rlast  ;
    logic [C_S_AXI_RUSER_WIDTH-1:0] axi_ruser  ;
    logic                           axi_rvalid ;

    logic aw_wrap_en;
    logic ar_wrap_en;

    logic [31:0] aw_wrap_size;
    logic [31:0] ar_wrap_size;

    logic axi_awv_awr_flag;
    logic axi_arv_arr_flag;

    logic [7:0] axi_awlen_cntr;
    logic [7:0] axi_arlen_cntr;
    logic [1:0] axi_arburst   ;
    logic [1:0] axi_awburst   ;
    logic [7:0] axi_arlen     ;
    logic [7:0] axi_awlen     ;

    localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32)+ 1;
    localparam integer OPT_MEM_ADDR_BITS = 5;
//----------------------------------------------
//-- Signals for user logic memory space example
//------------------------------------------------
    logic [   OPT_MEM_ADDR_BITS:0] mem_address ;

    genvar i;
    genvar j;
    genvar mem_byte_index;

    // I/O Connections assignments
    always_comb S_AXI_AWREADY = axi_awready;
    always_comb S_AXI_WREADY  = axi_wready;
    always_comb S_AXI_BRESP   = axi_bresp;
    always_comb S_AXI_BUSER   = axi_buser;
    always_comb S_AXI_BVALID  = axi_bvalid;
    always_comb S_AXI_ARREADY = axi_arready;
    always_comb S_AXI_RDATA   = axi_rdata;
    always_comb S_AXI_RRESP   = axi_rresp;
    always_comb S_AXI_RLAST   = axi_rlast;
    always_comb S_AXI_RUSER   = axi_ruser;
    
    
    always_comb S_AXI_BID     = S_AXI_AWID;
    always_comb S_AXI_RID     = S_AXI_ARID;
    always_comb aw_wrap_size  = (C_S_AXI_DATA_WIDTH/8 * (axi_awlen));
    always_comb ar_wrap_size  = (C_S_AXI_DATA_WIDTH/8 * (axi_arlen));
    always_comb aw_wrap_en    = ((axi_awaddr & aw_wrap_size) == aw_wrap_size)? 1'b1: 1'b0;
    always_comb ar_wrap_en    = ((axi_araddr & ar_wrap_size) == ar_wrap_size)? 1'b1: 1'b0;

    always_comb S_AXI_RVALID = axi_rvalid;


    always_ff @(posedge S_AXI_ACLK) begin
        if ( !S_AXI_ARESETN ) begin
            axi_awready      <= 1'b0;
            axi_awv_awr_flag <= 1'b0;
        end else begin
            if (~axi_awready && S_AXI_AWVALID && ~axi_awv_awr_flag && ~axi_arv_arr_flag) begin
                axi_awready      <= 1'b1;
                axi_awv_awr_flag <= 1'b1;
            end else begin 
                if (S_AXI_WLAST && axi_wready) begin
                    axi_awv_awr_flag <= 1'b0;
                end else begin
                    axi_awready <= 1'b0;
                end
            end 
        end
    end



    always_ff @(posedge S_AXI_ACLK) begin
        if ( !S_AXI_ARESETN ) begin
            axi_awaddr     <= 0;
            axi_awlen_cntr <= 0;
            axi_awburst    <= 0;
            axi_awlen      <= 0;
        end else begin
            if (~axi_awready && S_AXI_AWVALID && ~axi_awv_awr_flag) begin
                // address latching
                axi_awaddr     <= S_AXI_AWADDR[C_S_AXI_ADDR_WIDTH - 1:0];
                axi_awburst    <= S_AXI_AWBURST;
                axi_awlen      <= S_AXI_AWLEN;
                // start address of transfer
                axi_awlen_cntr <= 0;
            end else begin 
                if((axi_awlen_cntr <= axi_awlen) && axi_wready && S_AXI_WVALID) begin
                    axi_awlen_cntr <= axi_awlen_cntr + 1;

                    case (axi_awburst)
                        
                        2'b00 : begin 
                            axi_awaddr <= axi_awaddr; 
                        end
                        
                        2'b01 : begin
                            axi_awaddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] <= axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                            axi_awaddr[ADDR_LSB-1:0]                  <= {ADDR_LSB{1'b0}};
                        end
                        
                        2'b10 : begin 
                            if (aw_wrap_en) begin
                                axi_awaddr <= (axi_awaddr - aw_wrap_size);
                            end else begin
                                axi_awaddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] <= axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                                axi_awaddr[ADDR_LSB-1:0]                  <= {ADDR_LSB{1'b0}};
                            end
                        end 

                        default : begin 
                            axi_awaddr <= axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1; 
                        end

                    endcase
                end
            end 
        end
    end  



    always_ff @(posedge S_AXI_ACLK) begin
        if ( !S_AXI_ARESETN ) begin
            axi_wready <= 1'b0;
        end else begin
            if ( ~axi_wready && S_AXI_WVALID && axi_awv_awr_flag) begin
                axi_wready <= 1'b1;
            end else begin 
                if (S_AXI_WLAST && axi_wready) begin
                    axi_wready <= 1'b0;
                end
            end 
        end
    end       



    always_ff @(posedge S_AXI_ACLK) begin
        if ( !S_AXI_ARESETN ) begin
            axi_bvalid <= 0;
            axi_bresp  <= 2'b0;
            axi_buser  <= 0;
        end else begin
            if (axi_awv_awr_flag && axi_wready && S_AXI_WVALID && ~axi_bvalid && S_AXI_WLAST ) begin
                axi_bvalid <= 1'b1;
                axi_bresp  <= 2'b0;
            end else begin
                if (S_AXI_BREADY && axi_bvalid) begin
                    axi_bvalid <= 1'b0;
                end
            end
        end
    end   


/////////////////////////////////////////////////////////////
///////////////////// -= READ DOMAIN =- /////////////////////
/////////////////////////////////////////////////////////////

    always_ff @(posedge S_AXI_ACLK) begin : axi_arready_processing
        if ( !S_AXI_ARESETN ) begin
            axi_arready <= 1'b0;
        end else begin
            if (~axi_arready && S_AXI_ARVALID && ~axi_awv_awr_flag && ~axi_arv_arr_flag) begin
                axi_arready <= 1'b1;
            end else begin
                if (axi_rvalid && S_AXI_RREADY && axi_arlen_cntr == axi_arlen) begin
                    axi_arready <= axi_arready;
                end else begin
                    axi_arready <= 1'b0;
                end
            end
        end
    end       



    always_ff @(posedge S_AXI_ACLK) begin : axi_arv_arr_flag_processing 
        if ( !S_AXI_ARESETN ) begin
            axi_arv_arr_flag <= 1'b0;
        end else begin
            if (~axi_arready && S_AXI_ARVALID && ~axi_awv_awr_flag && ~axi_arv_arr_flag) begin
                axi_arv_arr_flag <= 1'b1;
            end else begin 
                if (axi_rvalid && S_AXI_RREADY && axi_arlen_cntr == axi_arlen) begin
                    axi_arv_arr_flag <= 1'b0;
                end else begin
                    axi_arv_arr_flag <= axi_arv_arr_flag;
                end
            end 
        end
    end       


    always_ff @(posedge S_AXI_ACLK) begin : axi_araddr_processing
        if ( !S_AXI_ARESETN ) begin
            axi_araddr <= 0;
        end else begin
            if (~axi_arready && S_AXI_ARVALID && ~axi_arv_arr_flag) begin
                axi_araddr <= S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH - 1:0];
            end else begin
                if((axi_arlen_cntr <= axi_arlen) && axi_rvalid && S_AXI_RREADY) begin
                    case (axi_arburst)
                        2'b00 : begin
                            axi_araddr <= axi_araddr;
                        end

                        2'b01 : begin
                            axi_araddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] <= axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                            axi_araddr[ADDR_LSB-1:0]                  <= {ADDR_LSB{1'b0}};
                        end
                        
                        2'b10 :
                            if (ar_wrap_en)
                                begin
                                    axi_araddr <= (axi_araddr - ar_wrap_size);
                                end else begin
                                    axi_araddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] <= axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                                    axi_araddr[ADDR_LSB-1:0]                  <= {ADDR_LSB{1'b0}};
                                end

                        default : begin
                            axi_araddr <= axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB]+1;
                        end

                    endcase
                end
            end
        end
    end


    always_ff @(posedge S_AXI_ACLK) begin : axi_arlen_cntr_processing 
        if ( !S_AXI_ARESETN ) begin
            axi_arlen_cntr <= 0;
        end else begin
            if (axi_arready && S_AXI_ARVALID && ~axi_arv_arr_flag) begin
                axi_arlen_cntr <= 0;
            end else begin 
                if((axi_arlen_cntr <= axi_arlen) && axi_rvalid && S_AXI_RREADY) begin
                    axi_arlen_cntr <= axi_arlen_cntr + 1;
                end else begin 
                    axi_arlen_cntr <= axi_arlen_cntr;
                end 
            end
        end 
    end



    always_ff @(posedge S_AXI_ACLK) begin : axi_arburst_cntr_processing
        if ( !S_AXI_ARESETN ) begin
            axi_arburst <= 0;
        end else begin
            if (~axi_arready && S_AXI_ARVALID && ~axi_arv_arr_flag) begin
                axi_arburst <= S_AXI_ARBURST;
            end else begin
                axi_arburst <= axi_arburst;
            end
        end
    end


    always_ff @(posedge S_AXI_ACLK) begin : axi_arlen_processing
        if ( !S_AXI_ARESETN ) begin
            axi_arlen <= 0;
        end else begin
            if (~axi_arready && S_AXI_ARVALID && ~axi_arv_arr_flag) begin
                axi_arlen <= S_AXI_ARLEN;
            end else begin
                axi_arlen <= axi_arlen;
            end
        end
    end



    always_ff @(posedge S_AXI_ACLK) begin : axi_ruser_processing
        if ( !S_AXI_ARESETN ) begin
            axi_ruser <= 0;
        end else begin
            axi_ruser <= axi_ruser;
        end
    end



    always_ff @(posedge S_AXI_ACLK) begin : axi_rlast_processing 
        if ( !S_AXI_ARESETN ) begin
            axi_rlast      <= 1'b0;
        end else begin
            if (~axi_arready && S_AXI_ARVALID && ~axi_arv_arr_flag) begin
                axi_rlast      <= 1'b0;
            end else begin 
                if((axi_arlen_cntr < axi_arlen) && axi_rvalid && S_AXI_RREADY) begin
                    axi_rlast      <= 1'b0;
                end else begin 
                    if((axi_arlen_cntr == axi_arlen) && ~axi_rlast && axi_arv_arr_flag ) begin
                        axi_rlast <= 1'b1;
                    end else begin 
                        if (S_AXI_RREADY) begin
                            axi_rlast <= 1'b0;
                        end else begin 
                            axi_rlast <= axi_rlast;
                        end 
                    end
                end 
            end
        end 
    end




    always_ff @(posedge S_AXI_ACLK) begin : axi_rvalid_processing 
        if ( !S_AXI_ARESETN ) begin
            axi_rvalid <= 1'b0;
        end else begin
            if (axi_arv_arr_flag && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
            end else begin 
                if (axi_rvalid && ~axi_arv_arr_flag) begin 
                    axi_rvalid <= 1'b0;
                end else begin 
                    axi_rvalid <= axi_rvalid;
                end 
                // if (axi_rvalid && S_AXI_RREADY) begin
                    // axi_rvalid <= axi_rvalid;
                // end else begin 
                    // axi_rvalid <= 1'b0;
                // end 
            end 
        end
    end



    always_ff @(posedge S_AXI_ACLK) begin : axi_rresp_processing 
        if ( !S_AXI_ARESETN ) begin
            axi_rresp  <= 0;
        end else begin
            if (axi_arv_arr_flag && ~axi_rvalid) begin
                axi_rresp  <= 2'b0;
            end else begin 
                axi_rresp <= axi_rresp;
            end 
        end
    end


// ------------------------------------------
// -- Example code to access user logic memory region
// ------------------------------------------

    always_comb mem_address = (axi_arv_arr_flag? axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]:
                              (axi_awv_awr_flag? axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]:
                               0));


    wire mem_rden;
    wire mem_wren;

    assign mem_wren = axi_wready && S_AXI_WVALID ;

    assign mem_rden = axi_arv_arr_flag ;

    logic       [31:0] data_in ;
    logic       [31:0] data_out;


    always_comb data_in = S_AXI_WDATA;

    always_comb axi_rdata = data_out;


    logic [3:0] wea;

    generate 
        for(mem_byte_index = 0; mem_byte_index <= 3; mem_byte_index = mem_byte_index + 1) begin
    
            always_comb wea[mem_byte_index] = mem_wren & S_AXI_WSTRB[mem_byte_index];
        end 

    endgenerate


    xpm_memory_tdpram #(
        .ADDR_WIDTH_A           (6              ),   // DECIMAL
        .ADDR_WIDTH_B           (6              ),   // DECIMAL
        .AUTO_SLEEP_TIME        (0              ),   // DECIMAL
        .BYTE_WRITE_WIDTH_A     (8              ),   // DECIMAL
        .BYTE_WRITE_WIDTH_B     (8              ),   // DECIMAL
        .CASCADE_HEIGHT         (0              ),   // DECIMAL
        .CLOCKING_MODE          ("common_clock" ),   // String
        .ECC_BIT_RANGE          ("7:0"          ),   // String
        .ECC_MODE               ("no_ecc"       ),   // String
        .ECC_TYPE               ("none"         ),   // String
        .IGNORE_INIT_SYNTH      (0              ),   // DECIMAL
        .MEMORY_INIT_FILE       ("none"         ),   // String
        .MEMORY_INIT_PARAM      ("0"            ),   // String
        .MEMORY_OPTIMIZATION    ("true"         ),   // String
        .MEMORY_PRIMITIVE       ("auto"         ),   // String
        .MEMORY_SIZE            (2048           ),   // DECIMAL
        .MESSAGE_CONTROL        (0              ),   // DECIMAL
        .RAM_DECOMP             ("auto"         ),   // String
        .READ_DATA_WIDTH_A      (32             ),   // DECIMAL
        .READ_DATA_WIDTH_B      (32             ),   // DECIMAL
        .READ_LATENCY_A         (1              ),   // DECIMAL
        .READ_LATENCY_B         (1              ),   // DECIMAL
        .READ_RESET_VALUE_A     ("0"            ),   // String
        .READ_RESET_VALUE_B     ("0"            ),   // String
        .RST_MODE_A             ("SYNC"         ),   // String
        .RST_MODE_B             ("SYNC"         ),   // String
        .SIM_ASSERT_CHK         (0              ),   // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_EMBEDDED_CONSTRAINT(0              ),   // DECIMAL
        .USE_MEM_INIT           (1              ),   // DECIMAL
        .USE_MEM_INIT_MMI       (0              ),   // DECIMAL
        .WAKEUP_TIME            ("disable_sleep"),   // String
        .WRITE_DATA_WIDTH_A     (32             ),   // DECIMAL
        .WRITE_DATA_WIDTH_B     (32             ),   // DECIMAL
        .WRITE_MODE_A           ("no_change"    ),   // String
        .WRITE_MODE_B           ("no_change"    ),   // String
        .WRITE_PROTECT          (1              )    // DECIMAL
    ) xpm_memory_tdpram_inst (
        .dbiterra      (              ),
        .dbiterrb      (              ),
        .douta         (data_out      ),
        .doutb         (              ),
        .sbiterra      (              ),
        .sbiterrb      (              ),
        .addra         (mem_address   ),
        .addrb         (6'b000000     ),
        .clka          (S_AXI_ACLK    ),
        .clkb          (S_AXI_ACLK    ),
        .dina          (data_in       ),
        .dinb          (32'h00000000  ),
        .ena           (1'b1          ),
        .enb           (1'b1          ),
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
        .web           (4'h0          )
    );


endmodule

