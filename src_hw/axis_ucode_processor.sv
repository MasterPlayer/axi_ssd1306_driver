

module axis_ucode_processor #(
    parameter integer SIZE_WIDTH = 16,
    parameter integer DATA_WIDTH = 32
) (
    input  logic                  i_clk               ,
    input  logic                  i_reset             ,
    //
    input  logic                  i_cfg_initialize    ,
    input  logic [           7:0] i_cfg_iic_address   ,
    //
    output logic [           5:0] o_addr              ,
    output logic                  o_en                ,
    input  logic [          31:0] i_din               ,
    //
    output logic [           7:0] o_write_cmd_iic_addr,
    output logic [SIZE_WIDTH-1:0] o_write_cmd_size    ,
    output logic                  o_write_cmd_valid   ,
    //
    output logic [DATA_WIDTH-1:0] o_s_axis_tdata      ,
    output logic                  o_s_axis_tlast      ,
    output logic                  o_s_axis_tvalid     ,
    input  logic                  i_s_axis_tready
    //
);

    logic [ 1:0] size       = '{default:0};
    logic        is_active  = 1'b0        ;
    logic [31:0] shift_register_data = '{default:0};

    typedef enum {
        RST_ST,
        IDLE_ST,

        READ_ST, 
        DECODE_ST,
        ANALYZE_CMD,
        PERFORM_OPERATION_ST,
        INC_PTR_ST,

        STUB_ST
    } fsm; 

    fsm current_state = RST_ST;

    always_ff @(posedge i_clk) begin : current_state_processing 
        if (i_reset) begin 
            current_state <= RST_ST;
        end else begin 

            case (current_state) 
                RST_ST : 
                    current_state <= IDLE_ST;

                IDLE_ST : 
                    if (i_cfg_initialize) begin 
                        current_state <= READ_ST;
                    end else begin 
                        current_state <= current_state;
                    end 
        
                READ_ST : 
                    current_state <= DECODE_ST; 

                DECODE_ST : 
                    current_state <= ANALYZE_CMD;

                ANALYZE_CMD : 
                    if (is_active) begin 
                        current_state <= PERFORM_OPERATION_ST;
                    end else begin 
                        current_state <= INC_PTR_ST;
                    end 

                PERFORM_OPERATION_ST : 
                    if (size) begin 
                        current_state <= current_state;
                    end else begin 
                        current_state <= INC_PTR_ST;
                    end 

                INC_PTR_ST : 
                    if (o_addr == 6'h3F) begin 
                        current_state <= IDLE_ST;
                    end else begin 
                        current_state <= READ_ST;
                    end 

                default : 
                    current_state <= current_state;

            endcase // current_state

        end 
    end 


    always_ff @(posedge i_clk) begin : o_addr_processing 
        case (current_state)
            IDLE_ST : 
                o_addr <= '{default:0};

            INC_PTR_ST : 
                o_addr <= o_addr + 1;

            default : 
                o_addr <= o_addr;

        endcase // current_state
    end 


    always_ff @(posedge i_clk) begin : o_en_processing 
        case (current_state)
            RST_ST : 
                o_en <= 1'b0;
            
            IDLE_ST : 
                if (i_cfg_initialize) begin 
                    o_en <= 1'b1;
                end else begin 
                    o_en <= 1'b0;
                end 

            default : 
                o_en <= o_en;

        endcase // current_state
    end 


    always_ff @(posedge i_clk) begin : size_processing
        case (current_state)
            DECODE_ST : 
                size <= i_din[25:24];

            PERFORM_OPERATION_ST : 
                size <= size - 1;

            default : 
                size <= size; 

        endcase // current_state_processing
    end 


    always_ff @(posedge i_clk) begin : is_active_processing 
        case (current_state)
            DECODE_ST : 
                is_active <= i_din[31];

            default : 
                is_active <= is_active;

        endcase // current_state
    end 


    always_ff @(posedge i_clk) begin : shift_register_data_processing 
        case (current_state)
            DECODE_ST : 
                shift_register_data <= i_din[31:0];

            PERFORM_OPERATION_ST : 
                shift_register_data[23:0] <= shift_register_data[31:8]; 

            default : 
                shift_register_data <= shift_register_data;
        endcase // current_state
    end 


    always_ff @(posedge i_clk) begin : o_s_axis_tdata_processing 
        case (current_state) 

            PERFORM_OPERATION_ST : 
                o_s_axis_tdata <= shift_register_data[7:0];

            default : 
                o_s_axis_tdata <= o_s_axis_tdata;
        endcase // current_state
    end 


    always_comb o_s_axis_tlast = (size == 0);


    always_ff @(posedge i_clk) begin : o_s_axis_tvalid_processing 
        case (current_state) 

            PERFORM_OPERATION_ST : 
                if (size) begin 
                    o_s_axis_tvalid <= 1'b1;
                end else begin 
                    o_s_axis_tvalid <= 1'b0;
                end 

            default : 
                o_s_axis_tvalid <= o_s_axis_tvalid;
        endcase // current_state
    end 


    always_ff @(posedge i_clk) begin : o_write_cmd_iic_addr_processing 
        case (current_state)
            IDLE_ST : 
                o_write_cmd_iic_addr <= i_cfg_iic_address;

            default : 
                o_write_cmd_iic_addr <= o_write_cmd_iic_addr;

        endcase // current_state
    end 


    always_ff @(posedge i_clk) begin : o_write_cmd_size_processing 
        case (current_state)
            DECODE_ST : 
                o_write_cmd_size <= shift_register_data[25:24];

            default : 
                o_write_cmd_size <= o_write_cmd_size;
        endcase // current_state
    end 


    always_ff @(posedge i_clk) begin : o_write_cmd_valid_processing 
        case (current_state)
            PERFORM_OPERATION_ST : 
                if (size == 0) begin 
                    o_write_cmd_valid <= 1'b1;
                end else begin 
                    o_write_cmd_valid <= 1'b0;
                end 

            default : 
                o_write_cmd_valid <= 1'b0;

        endcase // current_state
    end 



endmodule : axis_ucode_processor