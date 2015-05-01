//
// Copyright 2014-2015 Ettus Research LLC
//

module noc_block_pfb
  #(parameter NOC_ID = 64'hFF70_0000_0000_0000,
    parameter STR_SINK_FIFOSIZE = 11)
   (input bus_clk, input bus_rst,
    input ce_clk, input ce_rst,
    input  [63:0] i_tdata, input  i_tlast, input  i_tvalid, output i_tready,
    output [63:0] o_tdata, output o_tlast, output o_tvalid, input  o_tready,
    output [63:0] debug
    );
   
   /////////////////////////////////////////////////////////////
   //
   // RFNoC Shell
   //
   ////////////////////////////////////////////////////////////
   wire [31:0] 	  set_data;
   wire [7:0] 	  set_addr;
   wire 	  set_stb;
   
   wire [63:0] 	  cmdout_tdata, ackin_tdata;
   wire 	  cmdout_tlast, cmdout_tvalid, cmdout_tready, ackin_tlast, ackin_tvalid, ackin_tready;
   
   wire [63:0] 	  str_sink_tdata, str_src_tdata;
   wire 	  str_sink_tlast, str_sink_tvalid, str_sink_tready, str_src_tlast, str_src_tvalid, str_src_tready;
   
   noc_shell #(.NOC_ID(NOC_ID), .STR_SINK_FIFOSIZE(STR_SINK_FIFOSIZE)) inst_noc_shell
     (.bus_clk(bus_clk), .bus_rst(bus_rst),
      .i_tdata(i_tdata), .i_tlast(i_tlast), .i_tvalid(i_tvalid), .i_tready(i_tready),
      .o_tdata(o_tdata), .o_tlast(o_tlast), .o_tvalid(o_tvalid), .o_tready(o_tready),
      // Computer Engine Clock Domain
      .clk(ce_clk), .reset(ce_rst),
      // Control Sink
      .set_data(set_data), .set_addr(set_addr), .set_stb(set_stb), .rb_data(64'd0),
      // Control Source
      .cmdout_tdata(cmdout_tdata), .cmdout_tlast(cmdout_tlast), .cmdout_tvalid(cmdout_tvalid), .cmdout_tready(cmdout_tready),
      .ackin_tdata(ackin_tdata), .ackin_tlast(ackin_tlast), .ackin_tvalid(ackin_tvalid), .ackin_tready(ackin_tready),
      // Stream Sink
      .str_sink_tdata(str_sink_tdata), .str_sink_tlast(str_sink_tlast), .str_sink_tvalid(str_sink_tvalid), .str_sink_tready(str_sink_tready),
      // Stream Source
      .str_src_tdata(str_src_tdata), .str_src_tlast(str_src_tlast), .str_src_tvalid(str_src_tvalid), .str_src_tready(str_src_tready),
      .debug(debug));
   
   // //////////////////////////////////////////////////////////
   //
   // AXI Wrapper
   // Convert RFNoC Shell interface into AXI stream interface
   //
   ////////////////////////////////////////////////////////////
   localparam NUM_AXI_CONFIG_BUS = 1;
  
   wire [31:0] 	  m_axis_data_tdata;
   wire 	  m_axis_data_tlast;
   wire 	  m_axis_data_tvalid;
   wire 	  m_axis_data_tready;
   
   wire [31:0] 	  s_axis_data_tdata;
   wire 	  s_axis_data_tlast;
   wire 	  s_axis_data_tvalid;
   wire 	  s_axis_data_tready;
   
   wire [31:0] 	  m_axis_config_tdata;
   wire 	  m_axis_config_tlast;
   wire 	  m_axis_config_tvalid;
   wire 	  m_axis_config_tready;
   
   localparam AXI_WRAPPER_BASE    = 128;
   localparam SR_NEXT_DST         = AXI_WRAPPER_BASE;
   localparam SR_AXI_CONFIG_BASE  = AXI_WRAPPER_BASE + 1;

   // Set next destination in chain
   wire [15:0] next_dst;
   setting_reg #(
     .my_addr(SR_NEXT_DST), .width(16))
   sr_next_dst(
     .clk(ce_clk), .rst(ce_rst),
     .strobe(set_stb), .addr(set_addr), .in(set_data), .out(next_dst), .changed());

   axi_wrapper #(
      .SR_AXI_CONFIG_BASE(SR_AXI_CONFIG_BASE),
      .NUM_AXI_CONFIG_BUS(NUM_AXI_CONFIG_BUS))
   inst_axi_wrapper (
      .clk(ce_clk), .reset(ce_rst),
      .clear_tx_seqnum(clear_tx_seqnum),
      .next_dst(next_dst),
      .set_stb(set_stb), .set_addr(set_addr), .set_data(set_data),
      .i_tdata(str_sink_tdata), .i_tlast(str_sink_tlast), .i_tvalid(str_sink_tvalid), .i_tready(str_sink_tready),
      .o_tdata(str_src_tdata), .o_tlast(str_src_tlast), .o_tvalid(str_src_tvalid), .o_tready(str_src_tready),
      .m_axis_data_tdata(m_axis_data_tdata),
      .m_axis_data_tlast(m_axis_data_tlast),
      .m_axis_data_tvalid(m_axis_data_tvalid),
      .m_axis_data_tready(m_axis_data_tready),
      .s_axis_data_tdata(s_axis_data_tdata),
      .s_axis_data_tuser(128'h0),
      .s_axis_data_tlast(s_axis_data_tlast),
      .s_axis_data_tvalid(s_axis_data_tvalid),
      .s_axis_data_tready(s_axis_data_tready),
      .m_axis_config_tdata(m_axis_config_tdata),
      .m_axis_config_tlast(m_axis_config_tlast),
      .m_axis_config_tvalid(m_axis_config_tvalid), 
      .m_axis_config_tready(m_axis_config_tready));
   
   // //////////////////////////////////////////////////////////
   //
   // User code
   //
   ////////////////////////////////////////////////////////////
   
   // Control Source Unused
   assign cmdout_tdata = 64'd0;
   assign cmdout_tlast = 1'b0;
   assign cmdout_tvalid = 1'b0;
   assign ackin_tready = 1'b1;
   
   pfb #(.BASE(128),
	 .TAPS_PER_BIN(6),
	 .MAX_BINS_LOG2(10),
	 .WIDTH_IN(16),
	 .WIDTH_OUT(16),
	 .PWIDTH(48),
	 .CLIP_BITS(4)) pfb
     (.clk(ce_clk), .reset(ce_rst), .clear(1'b0),
      .set_stb(set_stb), .set_addr(set_addr), .set_data(set_data),
      .i_tdata(m_axis_data_tdata), .i_tlast(m_axis_data_tlast), .i_tvalid(m_axis_data_tvalid), .i_tready(m_axis_data_tready),
      .o_tdata(s_axis_data_tdata), .o_tlast(s_axis_data_tlast), .o_tvalid(s_axis_data_tvalid), .o_tready(s_axis_data_tready));
   
endmodule // noc_block_pfb