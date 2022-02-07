--------------------------------------------------------------------------------
-- Common Ethenet Package Fiel
-- Author: Niankun Rao
-- Date: 2022/02/06
-- Overview:
--   This file contains the common Ethernet constants and data types.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;

package ethernet_pkg is
  ------------------------------------------------------------------------------
  -- Ethernet Frame Format
  ------------------------------------------------------------------------------
  -- Ethernet preamble byte --
  constant PREAMBLE_BYTE : std_logic_vector(7 downto 0) := x"AA";
  -- Ethernet SFD byte --
  constant SFD_BYTE : std_logic_vector(7 downto 0) := x"D5";

  -- MAC address related --
  constant N_OF_BYTE_MAC : integer                                          := 6;
  constant BCAST_MAC     : std_logic_vector(N_OF_BYTE_MAC * 8 - 1 downto 0) := (others => '1');

  -- 802.1q VLAN related --
  constant C_VLAN_TPID            : std_logic_vector(15 downto 0) := x"8100"; -- C-TAG
  constant S_VLAN_TPID            : std_logic_vector(15 downto 0) := x"88A8"; -- S-TAG
  constant VLAN_ID_MAX            : integer                       := 4095;    -- max value of VLAN ID
  constant VLAN_ID_BIT_SIZE       : integer                       := integer(ceil(log2(real(VLAN_ID_MAX))));
  constant VLAN_PRIORITY_MAX      : integer                       := 7; -- max value of VLAN priority
  constant VLAN_PRIORITY_BIT_SIZE : integer                       := integer(ceil(log2(real(VLAN_PRIORITY_MAX))));

  -- Frame size related --
  constant MRU : integer := 1500; -- in unit of bytes
  constant MTU : integer := 1500; -- in unit of bytes
end package ethernet_pkg;