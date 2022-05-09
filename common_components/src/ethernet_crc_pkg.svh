////////////////////////////////////////////////////////////////////////////////
// Common package file for CRC calculation
// Author: Niankun Rao
// Date: 2022/05/09
// Overview:
//   This file contains the common functions for CRC calculation.
////////////////////////////////////////////////////////////////////////////////

`ifndef CRC_SVH
`define CRC_SVH

package ethernet_crc_pkg;

  parameter [31:0] ETHERNET_CRC32_INIT = '1;

  // This function calculates the CRC32 of the input 8-bit data.
  // @param[in] data: 8-bit data input
  // @param[in] crc_in: CRC initial value
  // @return CRC32 value
  // @remark This CRC32 calculation is based on the 802.3 Ethernet standard:
  // x^32 + x^26 + x^23 + x^22 + x^16 + x^12 + x^11 + x^10 + x^8 + x^7 + x^5 + x^4 + x^2 + x + 1
  function [31:0] crc32data8(input [7:0] din, input [31:0] crc_in);
    logic [31:0] crc_out;
    begin
      crc_out[0] = crc_in[24] ^ crc_in[30] ^ din[0] ^ din[6];
      crc_out[1] = crc_in[24] ^ crc_in[25] ^ crc_in[30] ^ crc_in[31] ^ din[0] ^ din[1] ^ din[6] ^ din[7];
      crc_out[2] = crc_in[24] ^ crc_in[25] ^ crc_in[26] ^ crc_in[30] ^ crc_in[31] ^ din[0] ^ din[1] ^ din[2] ^ din[6] ^ din[7];
      crc_out[3] = crc_in[25] ^ crc_in[26] ^ crc_in[27] ^ crc_in[31] ^ din[1] ^ din[2] ^ din[3] ^ din[7];
      crc_out[4] = crc_in[24] ^ crc_in[26] ^ crc_in[27] ^ crc_in[28] ^ crc_in[30] ^ din[0] ^ din[2] ^ din[3] ^ din[4] ^ din[6];
      crc_out[5] = crc_in[24] ^ crc_in[25] ^ crc_in[27] ^ crc_in[28] ^ crc_in[29] ^ crc_in[30] ^ crc_in[31] ^ din[0] ^ din[1] ^ din[3] ^ din[4] ^ din[5] ^ din[6] ^ din[7];
      crc_out[6] = crc_in[25] ^ crc_in[26] ^ crc_in[28] ^ crc_in[29] ^ crc_in[30] ^ crc_in[31] ^ din[1] ^ din[2] ^ din[4] ^ din[5] ^ din[6] ^ din[7];
      crc_out[7] = crc_in[24] ^ crc_in[26] ^ crc_in[27] ^ crc_in[29] ^ crc_in[31] ^ din[0] ^ din[2] ^ din[3] ^ din[5] ^ din[7];
      crc_out[8] = crc_in[0] ^ crc_in[24] ^ crc_in[25] ^ crc_in[27] ^ crc_in[28] ^ din[0] ^ din[1] ^ din[3] ^ din[4];
      crc_out[9] = crc_in[1] ^ crc_in[25] ^ crc_in[26] ^ crc_in[28] ^ crc_in[29] ^ din[1] ^ din[2] ^ din[4] ^ din[5];
      crc_out[10] = crc_in[2] ^ crc_in[24] ^ crc_in[26] ^ crc_in[27] ^ crc_in[29] ^ din[0] ^ din[2] ^ din[3] ^ din[5];
      crc_out[11] = crc_in[3] ^ crc_in[24] ^ crc_in[25] ^ crc_in[27] ^ crc_in[28] ^ din[0] ^ din[1] ^ din[3] ^ din[4];
      crc_out[12] = crc_in[4] ^ crc_in[24] ^ crc_in[25] ^ crc_in[26] ^ crc_in[28] ^ crc_in[29] ^ crc_in[30] ^ din[0] ^ din[1] ^ din[2] ^ din[4] ^ din[5] ^ din[6];
      crc_out[13] = crc_in[5] ^ crc_in[25] ^ crc_in[26] ^ crc_in[27] ^ crc_in[29] ^ crc_in[30] ^ crc_in[31] ^ din[1] ^ din[2] ^ din[3] ^ din[5] ^ din[6] ^ din[7];
      crc_out[14] = crc_in[6] ^ crc_in[26] ^ crc_in[27] ^ crc_in[28] ^ crc_in[30] ^ crc_in[31] ^ din[2] ^ din[3] ^ din[4] ^ din[6] ^ din[7];
      crc_out[15] = crc_in[7] ^ crc_in[27] ^ crc_in[28] ^ crc_in[29] ^ crc_in[31] ^ din[3] ^ din[4] ^ din[5] ^ din[7];
      crc_out[16] = crc_in[8] ^ crc_in[24] ^ crc_in[28] ^ crc_in[29] ^ din[0] ^ din[4] ^ din[5];
      crc_out[17] = crc_in[9] ^ crc_in[25] ^ crc_in[29] ^ crc_in[30] ^ din[1] ^ din[5] ^ din[6];
      crc_out[18] = crc_in[10] ^ crc_in[26] ^ crc_in[30] ^ crc_in[31] ^ din[2] ^ din[6] ^ din[7];
      crc_out[19] = crc_in[11] ^ crc_in[27] ^ crc_in[31] ^ din[3] ^ din[7];
      crc_out[20] = crc_in[12] ^ crc_in[28] ^ din[4];
      crc_out[21] = crc_in[13] ^ crc_in[29] ^ din[5];
      crc_out[22] = crc_in[14] ^ crc_in[24] ^ din[0];
      crc_out[23] = crc_in[15] ^ crc_in[24] ^ crc_in[25] ^ crc_in[30] ^ din[0] ^ din[1] ^ din[6];
      crc_out[24] = crc_in[16] ^ crc_in[25] ^ crc_in[26] ^ crc_in[31] ^ din[1] ^ din[2] ^ din[7];
      crc_out[25] = crc_in[17] ^ crc_in[26] ^ crc_in[27] ^ din[2] ^ din[3];
      crc_out[26] = crc_in[18] ^ crc_in[24] ^ crc_in[27] ^ crc_in[28] ^ crc_in[30] ^ din[0] ^ din[3] ^ din[4] ^ din[6];
      crc_out[27] = crc_in[19] ^ crc_in[25] ^ crc_in[28] ^ crc_in[29] ^ crc_in[31] ^ din[1] ^ din[4] ^ din[5] ^ din[7];
      crc_out[28] = crc_in[20] ^ crc_in[26] ^ crc_in[29] ^ crc_in[30] ^ din[2] ^ din[5] ^ din[6];
      crc_out[29] = crc_in[21] ^ crc_in[27] ^ crc_in[30] ^ crc_in[31] ^ din[3] ^ din[6] ^ din[7];
      crc_out[30] = crc_in[22] ^ crc_in[28] ^ crc_in[31] ^ din[4] ^ din[7];
      crc_out[31] = crc_in[23] ^ crc_in[29] ^ din[5];

      return crc_out;
    end
  endfunction

endpackage : ethernet_crc_pkg

`endif
