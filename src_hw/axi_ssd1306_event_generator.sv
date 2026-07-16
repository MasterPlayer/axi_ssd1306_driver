

module axi_ssd1306_event_generator (
    input  logic        i_clk                    ,
    input  logic        i_resetn                 ,
    // configuration for this unit
    input  logic [31:0] i_cfg_duration           ,
    // input signal group
    input  logic        i_cfg_has_complete_ucode ,
    input  logic        i_cfg_has_complete_update,
    // output signal group
    output logic        has_event
);

    typedef enum {
        IDLE_ST , 
        EVENT_ST
    } fsm;

    fsm current_state = IDLE_ST;

    logic [31:0] duration_cnt;

    always_ff @(posedge i_clk, negedge i_resetn) begin : current_state_processing 
        if (~i_resetn) begin 
            current_state <= IDLE_ST;
        end else begin 

            case (current_state)
                IDLE_ST : 
                    if (i_cfg_has_complete_ucode | i_cfg_has_complete_update) begin 
                        current_state <= EVENT_ST;
                    end else begin 
                        current_state <= current_state;
                    end 

                EVENT_ST : 
                    if (duration_cnt == 0) begin 
                        current_state <= IDLE_ST;
                    end else begin 
                        current_state <= current_state;
                    end 

                default : 
                    current_state <= current_state;

            endcase // current_state

        end 
    end  


    always_ff @(posedge i_clk, negedge i_resetn) begin : duration_cnt_processing 
        if (~i_resetn) begin 
            duration_cnt <= '{default:0};
        end else begin 

            case (current_state)
                IDLE_ST : 
                    duration_cnt <= i_cfg_duration;

                EVENT_ST : 
                    duration_cnt <= duration_cnt - 1;

            endcase // current_state

        end 
    end 
    

    always_ff @(posedge i_clk, negedge i_resetn) begin : has_event_processing 
        if (~i_resetn) begin 
            has_event <= 1'b0;
        end else begin 
            case (current_state)
                EVENT_ST : 
                    has_event <= 1'b1;

                default : 
                    has_event <= 1'b0;

            endcase // current_state
        end 
    end 


endmodule : axi_ssd1306_event_generator