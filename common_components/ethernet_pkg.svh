////////////////////////////////////////////////////////////////////////////////
// Common Ethenet Package File
// Author: Niankun Rao
// Date: 2022/02/06
// Overview:
//   This file contains the common Ethernet parameters and data types.
////////////////////////////////////////////////////////////////////////////////

`ifndef ETHERNET_PKG_H
`define ETHERNET_PKG_H

package ethernet_pkg;
  //////////////////////////////////////////////////////////////////////////////
  // Ethernet Frame Format
  //////////////////////////////////////////////////////////////////////////////
  // Ethernet preamble byte
  parameter logic [7:0] PREAMBLE_BYTE = 8'hAA;
  // Ethernet SFD byte
  parameter logic [7:0] SFD_BYTE = 8'hD5;

  // MAC address related
  parameter N_OF_BYTE_MAC = 6;
  parameter logic [N_OF_BYTE_MAC * 8 - 1:0] BCAST_MAC = '1;

  // 802.1q VLAN related
  parameter logic [15:0] C_VLAN_TPID = 16'h8100;  // C-TAG
  parameter logic [15:0] S_VLAN_TPID = 16'h88A8;  // S-TAG
  parameter VLAN_ID_MAX = 4095;  // max value of VLAN ID
  parameter VLAN_ID_BIT_WIDTH = $clog2(VLAN_ID_MAX);
  parameter VLAN_PRIORITY_MAX = 7;  // max value of VLAN priority
  parameter VLAN_PRIORITY_BIT_WIDTH = $clog2(VLAN_PRIORITY_MAX);
  parameter N_OF_BYTE_QVLAN = 4;
  parameter LEVEL_OF_QVLAN = 2;  // levels of Q-in-Q

  // Ethertype related
  parameter N_OF_BYTE_ETHERTYPE = 2;

  // FCS related
  parameter N_OF_BYTE_FCS = 4;

  // Frame size related
  parameter MTU = 1500;  // in unit of bytes
  // maximum size of frame in unit of byte:
  //   DMAC + SMAC + QTAG + Ethertype + payload + FCS
  parameter N_OF_BYTE_FRAME_MAX  = 2 * N_OF_BYTE_MAC + LEVEL_OF_QVLAN * N_OF_BYTE_QVLAN + N_OF_BYTE_ETHERTYPE + MTU + N_OF_BYTE_FCS;
  parameter FRAME_SIZE_BIT_WIDTH = $clog2(N_OF_BYTE_FRAME_MAX);

endpackage

`endif
