


module axi_ssd1306_update_processor #(
    parameter integer AXI_ADDR_WIDTH  = 32,
    parameter integer AXI_DATA_WIDTH  = 32,
    parameter         AXIS_DATA_WIDTH = 32,
    parameter         AXIS_DEPTH      = 32,
    parameter         SIZE_WIDTH      = 8
) (
    input  logic                         i_clk                ,
    input  logic                         i_resetn             ,
    input  logic [   AXI_ADDR_WIDTH-1:0] i_cfg_axi_baseaddress,
    input  logic [                  7:0] i_cfg_iic_address    ,
    input  logic                         i_cfg_update_screen  ,
    // interface to memory
    output logic [   AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR         ,
    output logic [                  7:0] M_AXI_ARLEN          ,
    output logic [                  2:0] M_AXI_ARSIZE         ,
    output logic [                  1:0] M_AXI_ARBURST        ,
    output logic                         M_AXI_ARVALID        ,
    input  logic                         M_AXI_ARREADY        ,
    input  logic [   AXI_DATA_WIDTH-1:0] M_AXI_RDATA          ,
    input  logic [                  1:0] M_AXI_RRESP          ,
    input  logic                         M_AXI_RLAST          ,
    input  logic                         M_AXI_RVALID         ,
    output logic                         M_AXI_RREADY         ,
    //
    output logic [                  7:0] WRITE_CMD_IIC_ADDR   ,
    output logic [       SIZE_WIDTH-1:0] WRITE_CMD_SIZE       ,
    output logic                         WRITE_CMD_VALID      ,
    output logic [(AXIS_DATA_WIDTH-1):0] M_AXIS_TDATA         ,
    output logic                         M_AXIS_TLAST         ,
    output logic                         M_AXIS_TVALID        ,
    input  logic                         M_AXIS_TREADY
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

    fsm current_state = IDLE_ST;

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
                    if (M_AXI_ARVALID & M_AXI_ARREADY) begin 
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
                    if (M_AXIS_TREADY) begin 
                        if (word_counter == 1) begin 
                            current_state <= TX_CMD_SET_DATA_ST;
                        end else begin 
                            current_state <= current_state;
                        end 
                    end else begin 
                        current_state <= current_state;
                    end 

                TX_CMD_SET_DATA_ST : 
                    if (M_AXIS_TREADY) begin 
                        current_state <= TX_DATA_ST;
                    end else begin 
                        current_state <= current_state;
                    end 

                TX_DATA_ST : 
                    if (M_AXIS_TREADY) begin 
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
                    if (M_AXIS_TREADY) begin 
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
                    if (M_AXIS_TREADY) begin 
                        if (word_counter == 1) begin 
                            word_counter <= '{default:0};
                        end else begin 
                            word_counter <= word_counter + 1;
                        end 
                    end else begin 
                        word_counter <= word_counter;
                    end 

                TX_DATA_ST : 
                    if (M_AXIS_TREADY) begin 
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
                    if (M_AXIS_TREADY) begin 
                        byte_counter <= byte_counter + 1;
                    end else begin 
                        byte_counter <= byte_counter;
                    end 

                default : 
                    byte_counter <= '{default:0};
            endcase // current_state
        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : M_AXI_ARADDR_processing 
        if (~i_resetn) begin 
            M_AXI_ARADDR <= '{default:0};
        end else begin 
            case (current_state)
                IDLE_ST : 
                    M_AXI_ARADDR <= i_cfg_axi_baseaddress;

                default : 
                    M_AXI_ARADDR <= M_AXI_ARADDR;

            endcase
        end
    end 


    always_comb M_AXI_ARSIZE = 3'b010;
    always_comb M_AXI_ARLEN  = 8'hFF;
    always_comb M_AXI_ARBURST = 2'b01;


    always_ff @(posedge i_clk, negedge i_resetn) begin : M_AXI_ARVALID_processing 
        if (~i_resetn) begin 
            M_AXI_ARVALID <= 1'b0;
        end else begin 

            case (current_state)
                IDLE_ST : 
                    M_AXI_ARVALID <= 1'b0;

                ESTABLISH_ADDRESS_ST : 
                    if (M_AXI_ARREADY & M_AXI_ARVALID) begin 
                        M_AXI_ARVALID <= 1'b0;
                    end else begin 
                        M_AXI_ARVALID <= 1'b1;
                    end 

                default : 
                    M_AXI_ARVALID <= 1'b0;

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
        .i_s_axis_tdata (M_AXI_RDATA       ),
        .i_s_axis_tstrb (                  ),
        .i_s_axis_tkeep (                  ),
        .i_s_axis_tid   (                  ),
        .i_s_axis_tdest (                  ),
        .i_s_axis_tuser (                  ),
        .i_s_axis_tlast (M_AXI_RLAST       ),
        .i_s_axis_tvalid(M_AXI_RVALID      ),
        .o_s_axis_tready(M_AXI_RREADY      ),
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


    always_comb axi_fifo_rden = M_AXIS_TREADY & (byte_counter == 3);


    always_ff @(posedge i_clk, negedge i_resetn) begin : M_AXIS_TDATA_processing 
        if (~i_resetn) begin 
            M_AXIS_TDATA <= '{default:0};
        end else begin 
            case (current_state)

                TX_CMD_SET_SEGMENT_ADDRESS_ST : 
                    if (M_AXIS_TREADY) begin 
                        case (word_counter)
                            0 : M_AXIS_TDATA <= 8'h00;
                            1 : M_AXIS_TDATA <= segment_address;
                            default : M_AXIS_TDATA <= M_AXIS_TDATA;
                        endcase // word_counter
                    end else begin 
                        M_AXIS_TDATA <= M_AXIS_TDATA;
                    end     

                TX_CMD_SET_DATA_ST : 
                    if (M_AXIS_TREADY) begin 
                        M_AXIS_TDATA <= 8'h40;
                    end else begin  
                        M_AXIS_TDATA <= M_AXIS_TDATA;
                    end 

                TX_DATA_ST :
                    if (M_AXIS_TREADY) begin
                        case (byte_counter)
                            2'b00 : M_AXIS_TDATA <= axi_fifo_dout_data[ 7: 0];
                            2'b01 : M_AXIS_TDATA <= axi_fifo_dout_data[15: 8];
                            2'b10 : M_AXIS_TDATA <= axi_fifo_dout_data[23:16];
                            2'b11 : M_AXIS_TDATA <= axi_fifo_dout_data[31:24];
                            default : M_AXIS_TDATA <= M_AXIS_TDATA;
                        endcase // byte_counter
                    end else begin
                        M_AXIS_TDATA <= M_AXIS_TDATA;
                    end 

                default : 
                    M_AXIS_TDATA <= M_AXIS_TDATA;

            endcase 
        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : M_AXIS_TLAST_processing
        if (~i_resetn) begin 
            M_AXIS_TLAST <= 1'b0;
        end else begin  
            case (current_state)
                TX_CMD_SET_SEGMENT_ADDRESS_ST: 
                    if (M_AXIS_TREADY)
                        case (word_counter)
                            1 : M_AXIS_TLAST <= 1'b1;
                            default : M_AXIS_TLAST <= 1'b0;
                        endcase // word_counter

                TX_CMD_SET_DATA_ST : 
                    if (M_AXIS_TREADY) begin 
                        M_AXIS_TLAST <= 1'b0;
                    end else begin 
                        M_AXIS_TLAST <= M_AXIS_TLAST;
                    end 

                TX_DATA_ST : 
                    if (M_AXIS_TREADY) begin 
                        if (word_counter == 127) begin 
                            M_AXIS_TLAST <= 1'b1;
                        end else begin 
                            M_AXIS_TLAST <= 1'b0;
                        end 
                    end else begin 
                        M_AXIS_TLAST <= M_AXIS_TLAST;
                    end 

                CHECK_SEGMENT_ADDRESS_ST : 
                    if (M_AXIS_TREADY) begin 
                        M_AXIS_TLAST <= 1'b0;
                    end else begin 
                        M_AXIS_TLAST <= M_AXIS_TLAST;
                    end 

                default : 
                    M_AXIS_TLAST <= M_AXIS_TLAST;

            endcase // current_state
        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : M_AXIS_TVALID_processing 
        if (~i_resetn) begin 
            M_AXIS_TVALID <= 1'b0;
        end else begin 
            case (current_state)
                TX_CMD_SET_SEGMENT_ADDRESS_ST : 
                    if (M_AXIS_TREADY) begin 
                        M_AXIS_TVALID <= 1'b1;
                    end else begin 
                        M_AXIS_TVALID <= M_AXIS_TVALID;
                    end 

                TX_CMD_SET_DATA_ST: 
                    M_AXIS_TVALID <= 1'b1;

                TX_DATA_ST : 
                    M_AXIS_TVALID <= 1'b1;

                CHECK_SEGMENT_ADDRESS_ST : 
                    if (M_AXIS_TREADY) begin 
                        M_AXIS_TVALID <= 1'b0;
                    end else begin 
                        M_AXIS_TVALID <= M_AXIS_TVALID;
                    end 

                STUB_ST : 
                    if (M_AXIS_TREADY) begin 
                        M_AXIS_TVALID <= 1'b0;
                    end else begin 
                        M_AXIS_TVALID <= M_AXIS_TVALID;
                    end 

                default : 
                    M_AXIS_TVALID <= 1'b0;

            endcase // current_state
        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : WRITE_CMD_IIC_ADDR_processing 
        if (~i_resetn) begin 
            WRITE_CMD_IIC_ADDR <= '{default:0};
        end else begin 
            case (current_state)
                IDLE_ST : 
                    WRITE_CMD_IIC_ADDR <= i_cfg_iic_address;

                default : 
                    WRITE_CMD_IIC_ADDR <= WRITE_CMD_IIC_ADDR;

            endcase // current_state
        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : WRITE_CMD_SIZE_processing 
        if (~i_resetn) begin 
            WRITE_CMD_SIZE <= '{default:0};
        end else begin 
            case (current_state)
                TX_CMD_SET_SEGMENT_ADDRESS_ST : 
                    if (M_AXIS_TREADY) begin 
                        if (word_counter == 1) begin 
                            WRITE_CMD_SIZE <= 8'h02;
                        end else begin 
                            WRITE_CMD_SIZE <= WRITE_CMD_SIZE;
                        end 
                    end else begin 
                        WRITE_CMD_SIZE <= WRITE_CMD_SIZE;
                    end 

                TX_CMD_SET_DATA_ST : 
                    if (M_AXIS_TREADY) begin 
                        WRITE_CMD_SIZE <= 8'h81;
                    end else begin 
                        WRITE_CMD_SIZE <= WRITE_CMD_SIZE;
                    end 

                default : 
                    WRITE_CMD_SIZE <= WRITE_CMD_SIZE;
            endcase // current_state_processing
        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : WRITE_CMD_VALID_processing 
        if (~i_resetn) begin 
            WRITE_CMD_VALID <= 1'b0;
        end else begin 
            case (current_state)
                TX_CMD_SET_SEGMENT_ADDRESS_ST : 
                    if (M_AXIS_TREADY) begin 
                        if (word_counter == 1) begin 
                            WRITE_CMD_VALID <= 1'b1;
                        end else begin 
                            WRITE_CMD_VALID <= 1'b0;
                        end 
                    end else begin 
                        WRITE_CMD_VALID <= 1'b0;
                    end 

                TX_CMD_SET_DATA_ST : 
                    if (M_AXIS_TREADY) begin 
                        WRITE_CMD_VALID <= 1'b1;
                    end else begin 
                        WRITE_CMD_VALID <= 1'b0;
                    end 

                default : 
                    WRITE_CMD_VALID <= 1'b0;
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
                    if (M_AXIS_TREADY) begin 
                        segment_address <= segment_address + 1;
                    end else begin 
                        segment_address <= segment_address;
                    end         

                default : 
                    segment_address <= segment_address;
            endcase // current_state
        end 
    end 

endmodule : axi_ssd1306_update_processor