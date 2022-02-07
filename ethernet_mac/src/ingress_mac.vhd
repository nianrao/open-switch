--------------------------------------------------------------------------------
-- Ingress MAC Module
-- Author: Niankun Rao
-- Date: 2022/02/06
-- Overview:
--   This module processes the incoming Ethernet byte stream, executes Layer 2
-- inspection and outputs the valid Ethernet frame to the core switch fabric.
--
-- Details:
--   This module executes the following Layer 2 inspections of the incoming
-- Ethernet frames:
--   1. Frame statistics:
--      total octets
--      total frames (including valid and invalid frames)
--      bad CRC frames
--      under-sized frames (size < 64-byte but good CRC)
--      over-sized frames (size > MRU byte but good CRC)
--      valid frames (valid size, good CRC):
--        broadcast frames
--        multicast frames
--        unicast frames
--   2. 802.1q VLAN processing:
--      VLAN-unaware mode: all tagged and untagged frames are accepted.
--      VLAN-aware mode: Untagged frames are accepted and internally tagged with
--                       the default VLAN ID = 1.
--                       Tagged frames whose VLAN ID is in the VLAN list are
--                       accepted.
--
-- Generic Table:
-- +----------------------------------------------------------------------------
-- | Generic name    | Data Type | Default Value
-- |----------------------------------------------------------------------------
-- | Description
-- +----------------------------------------------------------------------------
--
-- Port Table:
-- +----------------------------------------------------------------------------
-- | Port name       | Direction | Size, in bits | Domain      | Sense       |
-- |----------------------------------------------------------------------------
-- | Description
-- +----------------------------------------------------------------------------
-- +----------------------------------------------------------------------------
-- | reset           | input     | 1-bit         | N/A         | active high |
-- |----------------------------------------------------------------------------
-- | Set signal to high to reset this module
-- +----------------------------------------------------------------------------
-- +----------------------------------------------------------------------------
-- | lcl_clk         | input     | 1-bit         | N/A         | rising_edge |
-- |----------------------------------------------------------------------------
-- | Local clock running at 125MHz
-- +----------------------------------------------------------------------------
-- +----------------------------------------------------------------------------
-- | sof_in          | input     | 1-bit         | lcl_clk     | active high |
-- |----------------------------------------------------------------------------
-- | Start of frame signal. Asserted high for 1 clock cycle before the first
-- | data byte of an Ethernet frame.
-- +----------------------------------------------------------------------------
-- +----------------------------------------------------------------------------
-- | eof_in          | input     | 1-bit         | lcl_clk     | active high |
-- |----------------------------------------------------------------------------
-- | End of frame signal. Asserted high for 1 clock cycle at the last byte of
-- | an Ethernet frame.
-- +----------------------------------------------------------------------------
-- +----------------------------------------------------------------------------
-- | valid_in        | input     | 1-bit         | lcl_clk     | active high |
-- |----------------------------------------------------------------------------
-- | Data valid signal. Asserted high for 1 clock cycle if data_out is valid.
-- +----------------------------------------------------------------------------
-- +----------------------------------------------------------------------------
-- | data_in         | input     | 8-bit         | lcl_clk     | N/A         |
-- |----------------------------------------------------------------------------
-- | Data bus output of the stream of an Ethernet frame.
-- +----------------------------------------------------------------------------
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.ethernet_pkg.all;

entity ingress_mac is
  port (
    reset   : in std_logic;
    lcl_clk : in std_logic;

    -- incoming data stream --
    sof_in   : in std_logic;
    eof_in   : in std_logic;
    valid_in : in std_logic;
    data_in  : in std_logic_vector(7 downto 0);

    -- configurations --
    vlan_aware : in std_logic                     := '0';
    mru        : in std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(MRU, 11));

    -- outgoing data stream --
    sof_out   : out std_logic                      := '0';
    eof_out   : out std_logic                      := '0';
    valid_out : out std_logic                      := '0';
    data_out  : out std_logic_vector(127 downto 0) := (others => '0')
  );
end entity ingress_mac;

architecture rtl of ingress_mac is

begin

end architecture rtl;