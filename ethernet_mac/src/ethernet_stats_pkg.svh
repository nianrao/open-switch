////////////////////////////////////////////////////////////////////////////////
// Ethenet Statistics Package File
// Author: Niankun Rao
// Date: 2022/05/09
// Overview:
//   This file contains the Ethernet Statistics Package.
////////////////////////////////////////////////////////////////////////////////

`ifndef ETHERNET_STATS_PKG_SVH
`define ETHERNET_STATS_PKG_SVH

package ethernet_stats_pkg;
  typedef struct packed {
    logic valid_frame;
    logic bad_crc_frame;
    logic undersized_frame;
    logic oversized_frame;
    logic bcast_frame;
    logic mcast_frame;
    logic unicast_frame;
  } ether_stats_vector;

  parameter N_OF_ETHER_STATS_TYPE = $size(ether_stats_vector);

endpackage : ethernet_stats_pkg

`endif
