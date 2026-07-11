
module axis_ssd1306_mux #(
    parameter SIZE_WIDTH = 8,
    parameter DATA_WIDTH = 8
) (
    input                         selector              ,
    // data channel 0 : from ucode
    input  logic [           7:0] i_write_cmd_iic_addr_0,
    input  logic [SIZE_WIDTH-1:0] i_write_cmd_size_0    ,
    input  logic                  i_write_cmd_valid_0   ,
    //
    input  logic [DATA_WIDTH-1:0] i_s_axis_tdata_0      ,
    input  logic                  i_s_axis_tlast_0      ,
    input  logic                  i_s_axis_tvalid_0     ,
    output logic                  o_s_axis_tready_0     ,
    // data channel 1 : from internal logic
    input  logic [           7:0] i_write_cmd_iic_addr_1,
    input  logic [SIZE_WIDTH-1:0] i_write_cmd_size_1    ,
    input  logic                  i_write_cmd_valid_1   ,
    //
    input  logic [DATA_WIDTH-1:0] i_s_axis_tdata_1      ,
    input  logic                  i_s_axis_tlast_1      ,
    input  logic                  i_s_axis_tvalid_1     ,
    output logic                  o_s_axis_tready_1     ,
    // to iic bridge
    output logic [           7:0] o_write_cmd_iic_addr  ,
    output logic [SIZE_WIDTH-1:0] o_write_cmd_size      ,
    output logic                  o_write_cmd_valid     ,
    //
    output logic [DATA_WIDTH-1:0] o_m_axis_tdata        ,
    output logic                  o_m_axis_tlast        ,
    output logic                  o_m_axis_tvalid       ,
    input  logic                  i_m_axis_tready        
    //
);

    always_comb o_write_cmd_iic_addr = (selector) ? i_write_cmd_iic_addr_1 : i_write_cmd_iic_addr_0;
    always_comb o_write_cmd_size     = (selector) ? i_write_cmd_size_1 : i_write_cmd_size_0;
    always_comb o_write_cmd_valid    = (selector) ? i_write_cmd_valid_1 : i_write_cmd_valid_0;
    always_comb o_m_axis_tdata       = (selector) ? i_s_axis_tdata_1 : i_s_axis_tdata_0;
    always_comb o_m_axis_tlast       = (selector) ? i_s_axis_tlast_1 : i_s_axis_tlast_0;
    always_comb o_m_axis_tvalid      = (selector) ? i_s_axis_tvalid_1 : i_s_axis_tvalid_0;

    always_comb o_s_axis_tready_0 = (selector) ? 1'b0 : i_m_axis_tready; 

    always_comb o_s_axis_tready_1 = (selector) ? i_m_axis_tready : 1'b0;

endmodule : axis_ssd1306_mux