`timescale 1ps / 1ps


module axi_ssd1306_core #(
    parameter integer AXI_ADDR_WIDTH  = 32       ,
    parameter integer AXI_DATA_WIDTH  = 32       ,
    parameter         CLK_PERIOD      = 100000000,
    parameter         CLK_I2C_PERIOD  = 25000000 ,
    parameter         AXIS_DATA_WIDTH = 32       ,
    parameter         DEPTH           = 32       ,
    parameter         SIZE_WIDTH      = 8
) (
    input  logic                      i_clk            ,
    input  logic                      i_resetn         ,
    //
    input  logic                      i_update_screen  ,
    input  logic [AXI_ADDR_WIDTH-1:0] i_axi_baseaddress,
    input  logic [               6:0] i_cmd_iic_address,
    // interface to memory
    output logic [AXI_ADDR_WIDTH-1:0] o_m_axi_araddr   ,
    output logic [               7:0] o_m_axi_arlen    ,
    output logic [               2:0] o_m_axi_arsize   ,
    output logic [               1:0] o_m_axi_arburst  ,
    output logic                      o_m_axi_arvalid  ,
    input  logic                      i_m_axi_arready  ,
    //
    input  logic [AXI_DATA_WIDTH-1:0] i_m_axi_rdata    ,
    input  logic [               1:0] i_m_axi_rresp    ,
    input  logic                      i_m_axi_rlast    ,
    input  logic                      i_m_axi_rvalid   ,
    output logic                      o_m_axi_rready   ,
    //
    input  logic                      i_scl_i          ,
    input  logic                      i_sda_i          ,
    output logic                      o_scl_t          ,
    output logic                      o_sda_t
);

    typedef enum {
        IDLE_ST,
        ESTABLISH_ADDRESS_ST, 
        AWAIT_DATA_ST,

        TX_SET_SEGMENT_ADDRESS_ST,

        TX_CMD_DATA_ST,
        TX_DATA_ST,
        
        INCREMENT_SEGMENT_ADDRESS_ST,

        STUB_ST

    } fsm;

    logic [  (AXIS_DATA_WIDTH-1):0] s_axis_tdata;
    logic [                    7:0] s_axis_tuser;
    logic [(AXIS_DATA_WIDTH/8)-1:0] s_axis_tkeep;
    logic                           s_axis_tlast;
    logic                           s_axis_tvalid;
    logic                           s_axis_tready;

    logic [1:0] data_index = '{default:0};

    fsm current_state = IDLE_ST;

    logic [7:0] word_counter = '{default:0};

    logic [2:0] segment_index = '{default:0};


    logic [           7:0] write_cmd_iic_addr = '{default:0};
    logic [SIZE_WIDTH-1:0] write_cmd_size     = '{default:0};
    logic                  write_cmd_valid    = 1'b0;


    always_ff @(posedge i_clk) begin : current_state_processing 
        if (~i_resetn) begin 
            current_state <= IDLE_ST;
        end else begin 

            case (current_state)
                IDLE_ST : 
                    if (i_update_screen) begin 
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
                        current_state <= TX_SET_SEGMENT_ADDRESS_ST;
                    end else begin 
                        current_state <= current_state;
                    end 

                TX_SET_SEGMENT_ADDRESS_ST : 
                    if (s_axis_tready) begin 
                        if (word_counter == 1) begin 
                            current_state <= TX_CMD_DATA_ST;
                        end else begin 
                            current_state <= current_state;
                        end 
                    end else begin 
                        current_state <= current_state;
                    end 


                TX_CMD_DATA_ST : 
                    if (s_axis_tready) begin 
                        current_state <= TX_DATA_ST;
                    end else begin 
                        current_state <= current_state;
                    end 

                TX_DATA_ST : 
                    if (s_axis_tready & s_axis_tvalid & s_axis_tlast) begin 
                        current_state <= INCREMENT_SEGMENT_ADDRESS_ST;
                    end else begin 
                        current_state <= current_state;
                    end 

                INCREMENT_SEGMENT_ADDRESS_ST: 
                    if (segment_index == 7) begin 
                        current_state <= IDLE_ST;
                    end else begin 
                        current_state <= TX_SET_SEGMENT_ADDRESS_ST;
                    end 

                default : 
                    current_state <= current_state;

            endcase
        end 
    end 


    always_ff @(posedge i_clk) begin : word_counter_processing 
        case (current_state)
            TX_SET_SEGMENT_ADDRESS_ST : 
                if (s_axis_tready) begin 
                    word_counter <= word_counter + 1;
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


    always_ff @(posedge i_clk) begin : o_m_axi_araddr_processing 
        case (current_state)
            IDLE_ST : 
                o_m_axi_araddr <= i_axi_baseaddress;

            default : 
                o_m_axi_araddr <= o_m_axi_araddr;

        endcase
    end 


    always_comb o_m_axi_arsize = 3'b010;
    always_comb o_m_axi_arlen  = 8'hFF;
    always_comb o_m_axi_arburst = 2'b01;


    always_ff @(posedge i_clk) begin 
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


    logic [(AXI_DATA_WIDTH-1):0] axi_fifo_dout_data;
    logic                        axi_fifo_dout_last;
    logic                        axi_fifo_rden     ;
    logic                        axi_fifo_empty    ;


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
        .o_empty        (axi_fifo_empty    )
        //
    );

    always_comb axi_fifo_rden = (data_index == 2'b11) & s_axis_tready;


    axis_iic_bridge_cmd #(
        .CLK_PERIOD    (CLK_PERIOD     ),
        .CLK_I2C_PERIOD(CLK_I2C_PERIOD ),
        .DATA_WIDTH    (AXIS_DATA_WIDTH),
        .DEPTH         (DEPTH          ),
        .SIZE_WIDTH    (SIZE_WIDTH     )
    ) axis_iic_bridge_cmd_inst (
        .i_clk               (i_clk             ),
        .i_reset             (~i_resetn         ),
        //
        .i_write_cmd_iic_addr(write_cmd_iic_addr),
        .i_write_cmd_size    (write_cmd_size    ),
        .i_write_cmd_valid   (write_cmd_valid   ),
        //
        .i_s_axis_tdata      (s_axis_tdata      ),
        .i_s_axis_tkeep      (1'b1              ),
        .i_s_axis_tlast      (s_axis_tlast      ),
        .i_s_axis_tvalid     (s_axis_tvalid     ),
        .o_s_axis_tready     (s_axis_tready     ),
        //
        .i_read_cmd_iic_addr ('0                ),
        .i_read_cmd_size     ('0                ),
        .i_read_cmd_valid    (1'b0              ),
        //
        .o_m_axis_tdata      (                  ),
        .o_m_axis_tkeep      (                  ),
        .o_m_axis_tlast      (                  ),
        .o_m_axis_tvalid     (                  ),
        .i_m_axis_tready     (1'b0              ),
        //
        .i_scl_i             (i_scl_i           ),
        .i_sda_i             (i_sda_i           ),
        .o_scl_t             (o_scl_t           ),
        .o_sda_t             (o_sda_t           )
    );

    always_ff @(posedge i_clk) begin : write_cmd_iic_addr_processing 
        case (current_state)
            
            IDLE_ST : 
                write_cmd_iic_addr <= {i_cmd_iic_address, 1'b0};
            
            default : 
                write_cmd_iic_addr <= write_cmd_iic_addr;

        endcase // current_state
    end 



    always_ff @(posedge i_clk) begin : write_cmd_processing 
        case (current_state)
            TX_SET_SEGMENT_ADDRESS_ST : begin 
                if (s_axis_tready) begin 
                    if (word_counter == 0) begin 
                        write_cmd_size <= 8'h02; write_cmd_valid <= 1'b1;
                    end else begin 
                        write_cmd_size <= write_cmd_size; write_cmd_valid <= 1'b0;
                    end 
                end else begin 
                    write_cmd_size <= write_cmd_size; write_cmd_valid <= 1'b0;
                end 
            end 

            TX_CMD_DATA_ST : begin 
                if (s_axis_tready) begin 
                    write_cmd_size <= 8'h81; write_cmd_valid <= 1'b1;   
                end else begin 
                    write_cmd_size <= write_cmd_size; write_cmd_valid <= 1'b0;
                end 
            end 

            default : begin write_cmd_size <= 8'h00; write_cmd_valid <= 1'b0; end
        endcase // current_state
    end 



    always_ff @(posedge i_clk) begin : s_axis_tdata_processing 
        case (current_state)

            TX_SET_SEGMENT_ADDRESS_ST : 
                case (word_counter)
                    'd0 : s_axis_tdata <= 8'h00;
                    'd1 : s_axis_tdata <= 8'hB0 + segment_index;
                    default : s_axis_tdata <= s_axis_tdata;
                endcase // word_counter

            TX_CMD_DATA_ST : 
                s_axis_tdata <= 8'hC0;

            TX_DATA_ST : 
                if (s_axis_tready) begin 
                    case (data_index) 
                        2'b00   : s_axis_tdata <= axi_fifo_dout_data[ 7: 0];
                        2'b01   : s_axis_tdata <= axi_fifo_dout_data[15: 8];
                        2'b10   : s_axis_tdata <= axi_fifo_dout_data[23:16];
                        2'b11   : s_axis_tdata <= axi_fifo_dout_data[31:24];
                        default : s_axis_tdata <= s_axis_tdata;
                    endcase // data_index
                end else begin 
                    s_axis_tdata <= s_axis_tdata;
                end 

            default : s_axis_tdata <= s_axis_tdata;
        endcase
    end 


    always_ff @(posedge i_clk) begin : s_axis_tvalid_processing 
        case (current_state)

            TX_SET_SEGMENT_ADDRESS_ST : 
                if (s_axis_tready) begin 
                    if (s_axis_tlast) begin 
                        s_axis_tvalid <= 1'b0;
                    end else begin 
                        s_axis_tvalid <= 1'b1;
                    end 
                end else begin 
                    s_axis_tvalid <= 1'b1;
                end 

            TX_CMD_DATA_ST : 
                s_axis_tvalid <= 1'b1;

            TX_DATA_ST : 
                if (s_axis_tready) begin 
                    if (s_axis_tlast) begin 
                        s_axis_tvalid <= 1'b0;
                    end else begin 
                        s_axis_tvalid <= 1'b1;
                    end 
                end else begin 
                    s_axis_tvalid <= s_axis_tvalid;
                end 


            default : 
                s_axis_tvalid <= 1'b0;

        endcase // current_state
    end 


    always_ff @(posedge i_clk) begin : s_axis_tlast_processing 
        case (current_state)

            TX_SET_SEGMENT_ADDRESS_ST :
                if (word_counter == 1) begin 
                    s_axis_tlast <= 1'b1;
                end else begin 
                    s_axis_tlast <= 1'b0;
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

            default : 
                s_axis_tlast <= 1'b0;

        endcase // current_state
    end 


    always_ff @(posedge i_clk) begin : data_index_processing 
        case (current_state)
            TX_DATA_ST : 
                if (s_axis_tready & s_axis_tvalid) begin 
                    data_index <= data_index + 1;
                end else begin 
                    data_index <= data_index;
                end 

            default : 
                data_index <= '{default:0};

        endcase
    end 


    always_ff @(posedge i_clk) begin : segment_index_processing 
        case (current_state)
            INCREMENT_SEGMENT_ADDRESS_ST : 
                segment_index <= segment_index + 1;

            default : 
                segment_index <= segment_index;

        endcase // current_state
    end 

endmodule