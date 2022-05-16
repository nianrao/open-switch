////////////////////////////////////////////////////////////////////////////////
// Ingress MAC Module
// Author: Niankun Rao
// Date: 2022/05/09
// Overview:
//   This module processes the incoming Ethernet byte stream, executes Layer 2
// inspection and outputs the valid Ethernet frame.
//
// Details:
//   This module executes the following Layer 2 inspections of the incoming
// Ethernet frames:
//   1. Frame statistics:
//      total octets
//      total valid frames
//      bad CRC frames
//      under-sized frames (size < 64-bytes)
//      over-sized frames (size > MTU bytes)
//      valid frames (valid size, good CRC):
//        broadcast frames
//        multicast frames
//        unicast frames
//   2. 802.1q VLAN processing:
//      VLAN-unaware mode: all tagged and untagged frames are accepted.
//      VLAN-aware mode: Untagged frames are accepted and internally tagged with
//                       the default VLAN ID = 1.
//                       Tagged frames whose VLAN ID is in the VLAN list are
//                       accepted.
////////////////////////////////////////////////////////////////////////////////

`ifndef INGRESS_FRAME_PROCESS_SV
`define INGRESS_FRAME_PROCESS_SV

`default_nettype none

import ethernet_pkg::*;
import ethernet_stats_pkg::*;
import ethernet_crc_pkg::*;

module ingress_frame_process (
    input wire reset,
    input wire lcl_clk,

    // incoming data stream
    input wire i_sof,
    input wire i_eof,
    input wire i_valid,
    input wire [7:0] iv_din,

    // configurations
    input wire i_vlan_aware,
    input wire i_is_in_vlan_list,

    // statistics
    output logic o_stats_valid = 1'b0,
    output logic [FRAME_SIZE_BIT_WIDTH-1:0] ov_frame_size = '0,
    output ether_stats_vector o_stats_vector = '0,

    // frame flags
    output logic o_sof = 1'b0,
    output logic o_eof = 1'b0,
    output logic o_discard
);

  typedef enum {
    IDLE_ST,
    SMAC_ST,
    DMAC_ST,
    ETHERTYPE_ST,
    QTAG_ST,
    PAYLOAD_ST
  } ingress_mac_state_t;

  ingress_mac_state_t state = IDLE_ST;
  logic [3:0] state_count = 0;

  // frame metadata
  logic [(N_OF_BYTE_MAC - 1):0][7:0] smac_addr = '0;
  logic [(N_OF_BYTE_MAC - 1):0][7:0] dmac_addr = '0;
  logic [(N_OF_BYTE_ETHERTYPE - 1):0][7:0] ethertype = '0;

  // qtag[15:13] - priority
  // qtag[12] - CFI bit
  // qtag[11:0] - VLAN ID
  logic is_qtag = 1'b0;
  logic [(VLAN_ID_BIT_WIDTH + VLAN_PRIORITY_BIT_WIDTH + 1 - 1):0] qtag = '0;
  logic [(VLAN_ID_BIT_WIDTH - 1):0] qtag_id = DEFAULT_QTAG_ID;
  logic [(VLAN_PRIORITY_BIT_WIDTH - 1):0] qtag_priority = DEFAULT_QTAG_PRIORITY;

  // FCS
  logic [31:0] fcs_captured = '0;
  logic [31:0] fcs_calculated = '0;
  logic [31:0] fcs_calculated_delayed[N_OF_BYTE_FCS-1:0] = '{default: '0};

  // discard flags
  logic discard_smac = 1'b0;
  logic discard_qtag = 1'b0;
  logic discard_bad_crc = 1'b0;
  logic discard_bad_size = 1'b0;

  //////////////////////////////////////////////////////////////////////////////
  // SOF/EOF output: 1-cycle delay compared to its input version
  //////////////////////////////////////////////////////////////////////////////
  always_ff @(posedge lcl_clk) begin
    o_sof <= i_sof;
    o_eof <= i_eof;
  end

  //////////////////////////////////////////////////////////////////////////////
  // EOF discard decision
  //////////////////////////////////////////////////////////////////////////////
  always_ff @(posedge lcl_clk) begin : frame_discard_process
    if (i_eof) begin
      discard_smac <= (smac_addr == '0);
      discard_qtag <= (is_qtag && i_vlan_aware && !i_is_in_vlan_list) ||
                    (!is_qtag && i_vlan_aware);
      discard_bad_crc <= (fcs_captured != fcs_calculated[3]);
      discard_bad_size <= (ov_frame_size < N_OF_BYTE_FRAME_MIN) ||
                        (ov_frame_size > N_OF_BYTE_FRAME_MAX);
    end else begin
      {discard_smac, discard_qtag, discard_bad_crc, discard_bad_size} <= '0;
    end
  end : frame_discard_process

  assign o_discard = discard_smac ||
                     discard_qtag ||
                     discard_bad_crc ||
                     discard_bad_size;

  //////////////////////////////////////////////////////////////////////////////
  // Statistics
  //////////////////////////////////////////////////////////////////////////////
  always_ff @(posedge lcl_clk, posedge reset) begin : statistics_process
    if (reset) begin
      o_stats_valid  <= 1'b0;
      ov_frame_size  <= 0;
      o_stats_vector <= '0;
    end else begin
      if (i_sof) begin
        o_stats_valid  <= 1'b0;
        ov_frame_size  <= 0;
        o_stats_vector <= '0;
      end else if (i_valid) begin
        ov_frame_size <= ov_frame_size + 1;
      end else if (i_eof) begin
        o_stats_valid <= 1'b1;

        // packet size
        if (ov_frame_size < N_OF_BYTE_FRAME_MIN)
          o_stats_vector.under_size <= 1'b1;
        if (ov_frame_size > N_OF_BYTE_FRAME_MAX)
          o_stats_vector.over_size <= 1'b1;

        // broadcast/multicast/unicast
        if (dmac_addr == BCAST_MAC) o_stats_vector.broadcast <= 1'b1;
        else if (dmac_addr[5][0] == 1'b1) o_stats_vector.multicast <= 1'b1;
        else o_stats_vector.unicast <= 1'b1;

        // FCS check
        if (fcs_captured != fcs_calculated_delayed[3])
          o_stats_vector.bad_crc <= 1'b1;

        // valid frame check
        if (ov_frame_size >= N_OF_BYTE_FRAME_MIN &&
              ov_frame_size <= N_OF_BYTE_FRAME_MAX &&
              fcs_captured == fcs_calculated[3]) begin
          o_stats_vector.valid_frame <= 1'b1;
        end
      end
    end
  end : statistics_process

  //////////////////////////////////////////////////////////////////////////////
  // FCS checking
  //////////////////////////////////////////////////////////////////////////////
  always_ff @(posedge lcl_clk, posedge reset) begin : fcs_calculation_proc
    if (reset) begin
      fcs_captured   <= '0;
      fcs_calculated <= '0;
    end else begin
      if (i_sof) begin
        fcs_captured   <= '0;
        fcs_calculated <= ETHERNET_CRC32_INIT;
      end else if (i_valid) begin
        fcs_captured   <= {fcs_captured, iv_din};
        fcs_calculated <= crc32data8(iv_din, fcs_calculated);
      end
    end
  end : fcs_calculation_proc

  // Delay the FCS for 4 cycles since the FCS calculation should not include the
  // last 4 bytes of the frame (which is the embedded FCS bytes).
  always_ff @(posedge lcl_clk) begin : fcs_delay_proc
    for (int i = 0; i < $size(fcs_calculated_delayed); i = i + 1) begin
      fcs_calculated_delayed[i] <= i==0? fcs_calculated :
                                         fcs_calculated_delayed[i-1];
    end
  end : fcs_delay_proc

  //////////////////////////////////////////////////////////////////////////////
  // Main state machine
  //////////////////////////////////////////////////////////////////////////////
  always_ff @(posedge lcl_clk, posedge reset) begin : ingress_mac_fsm
    if (reset) begin
      state       <= IDLE_ST;
      state_count <= 0;
      is_qtag     <= 1'b0;
    end else begin
      case (state)
        SMAC_ST: begin
          if (i_valid) begin
            smac_addr   <= {smac_addr, iv_din};
            state_count <= state_count + 1;
            if (state_count == N_OF_BYTE_MAC - 1) begin
              state       <= DMAC_ST;
              state_count <= '0;
            end
          end else if (i_eof) begin
            state       <= IDLE_ST;
            state_count <= '0;
          end
        end

        DMAC_ST: begin
          if (i_valid) begin
            dmac_addr   <= {dmac_addr, iv_din};
            state_count <= state_count + 1;
            if (state_count == N_OF_BYTE_MAC - 1) begin
              state       <= ETHERTYPE_ST;
              state_count <= '0;
            end
          end else if (i_eof) begin
            state       <= IDLE_ST;
            state_count <= '0;
          end
        end

        ETHERTYPE_ST: begin
          if (i_valid) begin
            ethertype   <= {ethertype, iv_din};
            state_count <= state_count + 1;
            if (state_count == N_OF_BYTE_ETHERTYPE - 1) begin
              state_count <= '0;

              // check if the frame is a QTAG frame
              if ({ethertype[7:0], iv_din} == C_VLAN_TPID ||
                  {ethertype[7:0], iv_din} == S_VLAN_TPID) begin
                state   <= QTAG_ST;
                is_qtag <= 1'b1;
              end else begin
                state <= PAYLOAD_ST;
              end
            end
          end else if (i_eof) begin
            state       <= IDLE_ST;
            state_count <= '0;
          end
        end

        QTAG_ST: begin
          if (i_valid) begin
            state_count <= state_count + 1;
            qtag        <= {qtag, iv_din};
            if (state_count == N_OF_BYTE_QTAG - 1) begin
              state       <= PAYLOAD_ST;
              state_count <= '0;
            end
          end else if (i_eof) begin
            state       <= IDLE_ST;
            state_count <= '0;
          end
        end

        PAYLOAD_ST: begin
          if (i_eof) begin
            state       <= IDLE_ST;
            state_count <= '0;
          end
        end

        default: begin  // IDLE_ST
          if (i_sof) begin
            state       <= SMAC_ST;
            state_count <= 0;
            is_qtag     <= 1'b0;
          end
        end
      endcase
    end
  end : ingress_mac_fsm

endmodule : ingress_frame_process

`default_nettype wire

`endif  // INGRESS_FRAME_PROCESS_SV
