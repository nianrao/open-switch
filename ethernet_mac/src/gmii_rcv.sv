////////////////////////////////////////////////////////////////////////////////
// GMII Receiver Module
// Author: Niankun Rao
// Date: 2022/01/30
// Overview:
//   This module converts the standard GMII receiving signals in to a byte data
//   stream.
//
// Generic Table:
// +////////////////////////////////////////////////////////////////////////////
// | Generic name    | Data Type |
// |////////////////////////////////////////////////////////////////////////////
// | Description
// +////////////////////////////////////////////////////////////////////////////
//
// Port Table:
// +////////////////////////////////////////////////////////////////////////////
// | Port name       | Direction | Size, in bits | Domain      | Sense       |
// |////////////////////////////////////////////////////////////////////////////
// | Description
// +////////////////////////////////////////////////////////////////////////////
// +////////////////////////////////////////////////////////////////////////////
// | reset           | input     | 1-bit         | N/A         | active high |
// |////////////////////////////////////////////////////////////////////////////
// | Set signal to high to reset this module
// +////////////////////////////////////////////////////////////////////////////
// +////////////////////////////////////////////////////////////////////////////
// | gmii_rx_clk     | input     | 1-bit         | N/A         | rising_edge |
// |////////////////////////////////////////////////////////////////////////////
// | Clock of GMII RX interface running at 125MHz
// +////////////////////////////////////////////////////////////////////////////
// +////////////////////////////////////////////////////////////////////////////
// | gmii_rx_dv      | input     | 1-bit         | gmii_rx_clk | active high |
// |////////////////////////////////////////////////////////////////////////////
// | Data valid signal of GMII RX interface
// +////////////////////////////////////////////////////////////////////////////
// +////////////////////////////////////////////////////////////////////////////
// | gmii_rx_er      | input     | 1-bit         | gmii_rx_clk | active high |
// |////////////////////////////////////////////////////////////////////////////
// | Data error signal of GMII RX interface
// +////////////////////////////////////////////////////////////////////////////
// +////////////////////////////////////////////////////////////////////////////
// | gmii_rx_din     | input     | 8-bit         | gmii_rx_clk | N/A         |
// |////////////////////////////////////////////////////////////////////////////
// | Data bus of GMII RX interface
// +////////////////////////////////////////////////////////////////////////////
// +////////////////////////////////////////////////////////////////////////////
// | lcl_clk         | input     | 1-bit         | N/A         | rising_edge |
// |////////////////////////////////////////////////////////////////////////////
// | Local clock running at 125MHz
// +////////////////////////////////////////////////////////////////////////////
// +////////////////////////////////////////////////////////////////////////////
// | sof_out          | input     | 1-bit         | lcl_clk     | active high |
// |////////////////////////////////////////////////////////////////////////////
// | Start of frame signal. Asserted high for 1 clock cycle before the first
// | data byte of an Ethernet frame.
// +////////////////////////////////////////////////////////////////////////////
// +////////////////////////////////////////////////////////////////////////////
// | eof_out          | input     | 1-bit         | lcl_clk     | active high |
// |////////////////////////////////////////////////////////////////////////////
// | End of frame signal. Asserted high for 1 clock cycle at the last byte of
// | an Ethernet frame.
// +////////////////////////////////////////////////////////////////////////////
// +////////////////////////////////////////////////////////////////////////////
// | valid_out        | input     | 1-bit         | lcl_clk     | active high |
// |////////////////////////////////////////////////////////////////////////////
// | Data valid signal. Asserted high for 1 clock cycle if data_out is valid.
// +////////////////////////////////////////////////////////////////////////////
// +////////////////////////////////////////////////////////////////////////////
// | data _out        | input     | 8-bit         | lcl_clk     | N/A         |
// |////////////////////////////////////////////////////////////////////////////
// | Data bus output of the stream of an Ethernet frame.
// +////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

`ifndef GMII_RCV_SV
`define GMII_RCV_SV

`default_nettype none

import ethernet_pkg::*;

module gmii_rcv (
    input wire reset,

    // gmii rcv signals from PHY //
    input wire gmii_rx_clk,
    input wire gmii_rx_dv,
    input wire gmii_rx_er,
    input wire [7:0] gmii_rx_din,

    // rcv byte stream to the downstream modules //
    input wire lcl_clk,
    output reg sof_out = 1'b0,
    output reg eof_out = 1'b0,
    output reg valid_out = 1'b0,
    output reg [7:0] data_out = '0
);

  typedef enum logic [1:0] {
    IDLE,
    SFD,
    DATA
  } gmii_rx_state_t;
  gmii_rx_state_t       gmii_rx_state = IDLE;

  logic                 sof = 1'b0;
  logic                 valid = 1'b0;
  logic                 eof = 1'b0;
  logic           [7:0] rx_data = '0;

  localparam FIFO_DEPTH = 16;
  logic [                       7:0] fifo_rst = '1;
  logic [3 + $bits(rx_data) - 1 : 0] fifo_din;
  logic                              fifo_wr;
  logic                              fifo_empty;
  logic [   $bits(fifo_din) - 1 : 0] fifo_dout;
  logic                              fifo_rd = 1'b0;
  logic                              fifo_full;


  // GMII receving state machine
  always_ff @(posedge gmii_rx_clk, posedge reset) begin : gmii_rx_state_machine
    if (reset) begin
      sof           <= 0;
      eof           <= 0;
      valid         <= 0;
      rx_data       <= '0;
      gmii_rx_state <= IDLE;
    end else begin
      // initialize signals
      sof     <= 0;
      eof     <= 0;
      valid   <= 0;
      rx_data <= '0;

      case (gmii_rx_state)
        SFD: begin
          if (gmii_rx_dv && !gmii_rx_er && gmii_rx_din == SFD_BYTE) begin
            gmii_rx_state <= DATA;
            sof           <= 1;
          end else if (gmii_rx_dv && !gmii_rx_er && gmii_rx_din == PREAMBLE_BYTE) begin
            gmii_rx_state <= SFD;
          end else begin
            gmii_rx_state <= IDLE;
          end
        end

        DATA: begin
          if (gmii_rx_dv && !gmii_rx_er) begin
            gmii_rx_state <= DATA;
            valid         <= 1;
            rx_data       <= gmii_rx_din;
          end else begin
            gmii_rx_state <= IDLE;
            eof           <= 1;
          end
        end

        default: begin  // IDLE
          if (gmii_rx_dv && !gmii_rx_er && gmii_rx_din == PREAMBLE_BYTE && !fifo_full) begin
            gmii_rx_state <= SFD;
          end else begin
            gmii_rx_state <= IDLE;
          end

        end
      endcase
    end
  end

  // Asynchronous FIFO from gmii_rx_clk to lcl_clk
  // FIFO data structure:
  // bit[10] - sof
  // bit[9] - eof
  // bit[8] - data valid
  // bits[7:0] - data

  assign fifo_din = {sof, eof, valid, rx_data};
  assign fifo_wr  = sof | eof | valid;

  // reset for the FIFO
  always_ff @(posedge gmii_rx_clk, posedge reset) begin : fifo_reset_process
    if (reset) begin
      fifo_rst <= '1;
    end else begin
      fifo_rst <= fifo_rst >> 1;
    end
    ;
  end

  xpm_fifo_async #(
      .CASCADE_HEIGHT     (0),
      .CDC_SYNC_STAGES    (2),
      .DOUT_RESET_VALUE   ("0"),
      .ECC_MODE           ("no_ecc"),
      .FIFO_MEMORY_TYPE   ("auto"),
      .FIFO_READ_LATENCY  (0),
      .FIFO_WRITE_DEPTH   (FIFO_DEPTH),
      .FULL_RESET_VALUE   (0),
      .PROG_EMPTY_THRESH  (FIFO_DEPTH / 10),
      .PROG_FULL_THRESH   (9 * FIFO_DEPTH / 10),
      .RD_DATA_COUNT_WIDTH($clog2(FIFO_DEPTH) + 1),
      .READ_DATA_WIDTH    ($bits(fifo_dout)),
      .READ_MODE          ("fwft"),
      .RELATED_CLOCKS     (0),
      .SIM_ASSERT_CHK     (0),
      .USE_ADV_FEATURES   ("0000"),
      .WAKEUP_TIME        (0),
      .WRITE_DATA_WIDTH   ($bits(fifo_din)),
      .WR_DATA_COUNT_WIDTH($clog2(FIFO_DEPTH) + 1)
  ) gmii_rx_fifo (
      .almost_empty(),
      .almost_full(),
      .data_valid(),
      .dbiterr(),
      .dout(fifo_dout),
      .empty(fifo_empty),
      .full(fifo_full),
      .overflow(),
      .prog_empty(),
      .prog_full(),
      .rd_data_count(),
      .rd_rst_busy(),
      .sbiterr(),
      .underflow(),
      .wr_ack(),
      .wr_data_count(),
      .wr_rst_busy(),
      .din(fifo_din),
      .injectdbiterr(1'b0),
      .injectsbiterr(1'b0),
      .rd_clk(lcl_clk),
      .rd_en(fifo_rd),
      .rst(fifo_rst[0]),
      .sleep(1'b0),
      .wr_clk(gmii_rx_clk),
      .wr_en(fifo_wr)
  );

  always_ff @(posedge lcl_clk, posedge reset) begin : fifo_read_process
    if (reset) begin
      fifo_rd   <= 1'b0;
      sof_out   <= 1'b0;
      eof_out   <= 1'b0;
      valid_out <= 1'b0;
      data_out  <= '0;
    end else begin
      if (!fifo_empty) begin
        fifo_rd   <= 1'b1;
        sof_out   <= fifo_dout[$left(fifo_dout)];
        eof_out   <= fifo_dout[$left(fifo_dout)-1];
        valid_out <= fifo_dout[$left(fifo_dout)-2];
        data_out  <= fifo_dout[($bits(data_out)-1) : 0];
      end else begin
        fifo_rd   <= 1'b0;
        sof_out   <= 1'b0;
        eof_out   <= 1'b0;
        valid_out <= 1'b0;
        data_out  <= '0;
      end
    end
  end

endmodule

`default_nettype wire
`endif
