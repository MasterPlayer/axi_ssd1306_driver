

module axis_ucode_processor #(
    parameter integer SIZE_WIDTH = 16,
    parameter integer DATA_WIDTH = 32
) (
    input  logic                  i_clk             ,
    input  logic                  i_resetn          ,
    //
    input  logic                  i_cfg_initialize  ,
    input  logic [           7:0] i_cfg_iic_address ,
    output logic                  o_cfg_has_busy    ,
    output logic                  o_cfg_has_complete,
    //
    output logic [           5:0] o_addr            ,
    output logic                  o_en              ,
    input  logic [          31:0] i_din             ,
    //
    output logic [           7:0] WRITE_CMD_IIC_ADDR,
    output logic [SIZE_WIDTH-1:0] WRITE_CMD_SIZE    ,
    output logic                  WRITE_CMD_VALID   ,
    //
    output logic [DATA_WIDTH-1:0] M_AXIS_TDATA      ,
    output logic                  M_AXIS_TLAST      ,
    output logic                  M_AXIS_TVALID     ,
    input  logic                  M_AXIS_TREADY
    //
);

    logic [ 1:0] size               ;
    logic        is_active          ;
    logic [31:0] shift_register_data;

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

    always_ff @(posedge i_clk, negedge i_resetn) begin : current_state_processing 
        if (~i_resetn) begin 
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
                    if (M_AXIS_TREADY) begin
                        if (size) begin 
                            current_state <= current_state;
                        end else begin 
                            current_state <= INC_PTR_ST;
                        end 
                    end else begin 
                        current_state <= current_state;
                    end 

                INC_PTR_ST : 
                    if (M_AXIS_TREADY) begin 
                        if (o_addr == 6'h3F) begin 
                            current_state <= IDLE_ST;
                        end else begin 
                            current_state <= READ_ST;
                        end 
                    end else begin 
                        current_state <= current_state;
                    end 

                default : 
                    current_state <= current_state;

            endcase // current_state

        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : o_cfg_has_complete_processing
        if (~i_resetn) begin 
            o_cfg_has_complete <= 1'b0;
        end else begin 

            case (current_state)
                INC_PTR_ST : 
                    if (M_AXIS_TREADY) begin 
                        if (o_addr == 6'h3f) begin 
                            o_cfg_has_complete <= 1'b1;
                        end else begin 
                            o_cfg_has_complete <= 1'b0;
                        end 
                    end else begin 
                        o_cfg_has_complete <= 1'b0;
                    end 

                default : 
                    o_cfg_has_complete <= 1'b0;

            endcase // current_state

        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : o_cfg_has_busy_processing 
        if (~i_resetn) begin 
            o_cfg_has_busy <= 1'b0;
        end else begin 
            case (current_state)
                IDLE_ST : 
                    o_cfg_has_busy <= 1'b0;

                default : 
                    o_cfg_has_busy <= 1'b1;

            endcase // current_state
        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : o_addr_processing 
        if (~i_resetn) begin 
            o_addr <= '{default:0};
        end else begin 
            case (current_state)
                IDLE_ST : 
                    o_addr <= '{default:0};

                INC_PTR_ST : 
                    if (M_AXIS_TREADY) begin 
                        o_addr <= o_addr + 1;
                    end else begin 
                        o_addr <= o_addr;
                    end 

                default : 
                    o_addr <= o_addr;

            endcase // current_state
        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : o_en_processing 
        if (~i_resetn) begin 
            o_en <= 1'b0;
        end else begin 
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
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : size_processing
        if (~i_resetn) begin 
            size <= '{default:0};
        end else begin 
            case (current_state)
                DECODE_ST : 
                    size <= i_din[25:24];

                PERFORM_OPERATION_ST : 
                    if (M_AXIS_TREADY) begin 
                        size <= size - 1;
                    end else begin 
                        size <= size;
                    end 

                default : 
                    size <= size; 

            endcase // current_state_processing
        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : is_active_processing 
        if (~i_resetn) begin 
            is_active <= 1'b0;
        end else begin 
            case (current_state)
                DECODE_ST : 
                    is_active <= i_din[31];

                default : 
                    is_active <= is_active;

            endcase // current_state
        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : shift_register_data_processing 
        if (~i_resetn) begin 
            shift_register_data <= '{default:0};
        end else begin 

            case (current_state)
                DECODE_ST : 
                    shift_register_data <= i_din[31:0];

                PERFORM_OPERATION_ST : 
                    if (M_AXIS_TREADY) begin
                        shift_register_data[23:0] <= shift_register_data[31:8]; 
                    end else begin 
                        shift_register_data[23:0] <= shift_register_data[23:0];
                    end 

                default : 
                    shift_register_data <= shift_register_data;

            endcase // current_state
        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : M_AXIS_TDATA_processing 
        if (~i_resetn) begin 
            M_AXIS_TDATA <= '{default:0};
        end else begin 
            case (current_state) 

                PERFORM_OPERATION_ST : 
                    if (M_AXIS_TREADY) begin 
                        M_AXIS_TDATA <= shift_register_data[7:0];
                    end else begin 
                        M_AXIS_TDATA <= M_AXIS_TDATA;
                    end 

                default : 
                    M_AXIS_TDATA <= M_AXIS_TDATA;
            endcase // current_state
        end 
    end 


    always_comb M_AXIS_TLAST = (size == 0);


    always_ff @(posedge i_clk, negedge i_resetn) begin : M_AXIS_TVALID_processing 
        if (~i_resetn) begin 
            M_AXIS_TVALID <= 1'b0;
        end else begin 
            case (current_state) 
                PERFORM_OPERATION_ST : 
                    if (M_AXIS_TREADY) begin 
                        if (size) begin 
                            M_AXIS_TVALID <= 1'b1;
                        end else begin 
                            M_AXIS_TVALID <= 1'b0;
                        end 
                    end else begin 
                        M_AXIS_TVALID <= M_AXIS_TVALID;
                    end 

                default : 
                    M_AXIS_TVALID <= M_AXIS_TVALID;
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
                DECODE_ST : 
                    WRITE_CMD_SIZE <= i_din[25:24];

                default : 
                    WRITE_CMD_SIZE <= WRITE_CMD_SIZE;
            endcase // current_state
        end 
    end 


    always_ff @(posedge i_clk, negedge i_resetn) begin : WRITE_CMD_VALID_PROCESSING 
        if (~i_resetn) begin 
            WRITE_CMD_VALID <= 1'b0;
        end else begin 

            case (current_state)
                PERFORM_OPERATION_ST : 
                    if (M_AXIS_TREADY) begin 
                        if (size == 0) begin 
                            WRITE_CMD_VALID <= 1'b1;
                        end else begin 
                            WRITE_CMD_VALID <= 1'b0;
                        end 
                    end else begin 
                        WRITE_CMD_VALID <= 1'b0;
                    end 

                default : 
                    WRITE_CMD_VALID <= 1'b0;

            endcase // current_state
        end 
    end 



endmodule : axis_ucode_processor