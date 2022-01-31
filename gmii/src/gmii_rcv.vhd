--------------------------------------------------------------------------------
-- GMII Receiver Module
-- Author: Niankun Rao
-- Date: 2022/01/30
-- Overview:
--   This module converts the standard GMII receiving signals in to a byte data
--   stream.
--
-- Generic Table:
-- +----------------------------------------------------------------------------
-- | Generic name    | Data Type |
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
-- | gmii_rx_clk     | input     | 1-bit         | N/A         | rising_edge |
-- |----------------------------------------------------------------------------
-- | Clock of GMII RX interface running at 125MHz
-- +----------------------------------------------------------------------------
-- +----------------------------------------------------------------------------
-- | gmii_rx_dv      | input     | 1-bit         | gmii_rx_clk | active high |
-- |----------------------------------------------------------------------------
-- | Data valid signal of GMII RX interface
-- +----------------------------------------------------------------------------
-- +----------------------------------------------------------------------------
-- | gmii_rx_er      | input     | 1-bit         | gmii_rx_clk | active high |
-- |----------------------------------------------------------------------------
-- | Data error signal of GMII RX interface
-- +----------------------------------------------------------------------------
-- +----------------------------------------------------------------------------
-- | gmii_rx_din     | input     | 8-bit         | gmii_rx_clk | N/A         |
-- |----------------------------------------------------------------------------
-- | Data bus of GMII RX interface
-- +----------------------------------------------------------------------------
-- +----------------------------------------------------------------------------
-- | lcl_clk         | input     | 1-bit         | N/A         | rising_edge |
-- |----------------------------------------------------------------------------
-- | Local clock running at 125MHz
-- +----------------------------------------------------------------------------
-- +----------------------------------------------------------------------------
-- | sof_out          | input     | 1-bit         | lcl_clk     | active high |
-- |----------------------------------------------------------------------------
-- | Start of frame signal. Asserted high for 1 clock cycle before the first
-- | data byte of an Ethernet frame.
-- +----------------------------------------------------------------------------
-- +----------------------------------------------------------------------------
-- | eof_out          | input     | 1-bit         | lcl_clk     | active high |
-- |----------------------------------------------------------------------------
-- | End of frame signal. Asserted high for 1 clock cycle at the last byte of
-- | an Ethernet frame.
-- +----------------------------------------------------------------------------
-- +----------------------------------------------------------------------------
-- | valid_out        | input     | 1-bit         | lcl_clk     | active high |
-- |----------------------------------------------------------------------------
-- | Data valid signal. Asserted high for 1 clock cycle if data_out is valid.
-- +----------------------------------------------------------------------------
-- +----------------------------------------------------------------------------
-- | data _out        | input     | 8-bit         | lcl_clk     | N/A         |
-- |----------------------------------------------------------------------------
-- | Data bus output of the stream of an Ethernet frame.
-- +----------------------------------------------------------------------------
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;

library xpm;
use xpm.vcomponents.all;

entity gmii_rcv is
  port (
    -- gmii rcv signals from PHY --
    gmii_rx_clk : in std_logic;
    gmii_rx_dv  : in std_logic;
    gmii_rx_er  : in std_logic;
    gmii_rx_din : in std_logic_vector(7 downto 0);

    -- rcv byte stream to the downstream modules --
    lcl_clk   : in std_logic;
    sof_out   : out std_logic                    := '0';
    eof_out   : out std_logic                    := '0';
    valid_out : out std_logic                    := '0';
    data_out  : out std_logic_vector(7 downto 0) := (others => '0')
  );
end entity gmii_rcv;

architecture rtl of gmii_rcv is
  constant C_PREAMBLE_BYTE : std_logic_vector(7 downto 0) := x"AA";
  constant C_SFD_BYTE      : std_logic_vector(7 downto 0) := x"D5";

  type type_gmii_rx_state is (IDLE, SFD, DATA);
  signal gmii_rx_state : type_gmii_rx_state := IDLE;

  signal sof     : std_logic                    := '0';
  signal valid   : std_logic                    := '0';
  signal eof     : std_logic                    := '0';
  signal rx_data : std_logic_vector(7 downto 0) := (others => '0');

  constant FIFO_DEPTH : integer                      := 16;
  signal fifo_rst     : std_logic_vector(7 downto 0) := (others => '1');
  signal fifo_din     : std_logic_vector(3 + rx_data'length - 1 downto 0);
  signal fifo_wr      : std_logic;
  signal fifo_empty   : std_logic;
  signal fifo_dout    : std_logic_vector(fifo_din'length - 1 downto 0);
  signal fifo_rd      : std_logic := '0';

begin

  -- GMII receving state machine --
  gmii_rx_fsm : process (gmii_rx_clk) is
  begin
    if rising_edge(gmii_rx_clk) then
      -- initialize signals --
      sof     <= '0';
      eof     <= '0';
      valid   <= '0';
      rx_data <= (others => '0');

      case gmii_rx_state is
        when SFD =>
          if gmii_rx_dv = '1' and gmii_rx_er = '0' and gmii_rx_din = C_SFD_BYTE then
            gmii_rx_state <= DATA;
            sof           <= '1';
          elsif gmii_rx_dv = '1' and gmii_rx_er = '0' and gmii_rx_din = C_PREAMBLE_BYTE then
            gmii_rx_state <= SFD;
          else
            gmii_rx_state <= IDLE;
          end if;

        when DATA =>
          if gmii_rx_dv = '1' and gmii_rx_er = '0' then
            gmii_rx_state <= DATA;
            valid         <= '1';
            rx_data       <= gmii_rx_din;
          else
            gmii_rx_state <= IDLE;
            eof           <= '1';
          end if;

        when others => -- IDLE --
          if (gmii_rx_dv = '1' and gmii_rx_er = '0' and gmii_rx_din = C_PREAMBLE_BYTE) then
            gmii_rx_state <= SFD;
          else
            gmii_rx_state <= IDLE;
          end if;
      end case;
    end if;
  end process gmii_rx_fsm;

  -- Asynchronous FIFO from gmii_rx_clk to lcl_clk --
  -- FIFO data structure:
  -- bit[10] - sof
  -- bit[9] - eof
  -- bit[8] - data valid
  -- bits[7:0] - data

  fifo_din <= sof & eof & valid & rx_data;
  fifo_wr  <= sof or eof or valid;

  -- power-on reset for the FIFO --
  fifo_power_on_rst_proc : process (gmii_rx_clk) is
  begin
    if rising_edge(gmii_rx_clk) then
      fifo_rst <= '0' & fifo_rst(fifo_rst'left downto 1);
    end if;
  end process fifo_power_on_rst_proc;

  gmii_rx_fifo : xpm_fifo_async
  generic map(
    CASCADE_HEIGHT      => 0,                                         -- DECIMAL
    CDC_SYNC_STAGES     => 2,                                         -- DECIMAL
    DOUT_RESET_VALUE    => "0",                                       -- String
    ECC_MODE            => "no_ecc",                                  -- String
    FIFO_MEMORY_TYPE    => "auto",                                    -- String
    FIFO_READ_LATENCY   => 0,                                         -- DECIMAL
    FIFO_WRITE_DEPTH    => FIFO_DEPTH,                                -- DECIMAL
    FULL_RESET_VALUE    => 0,                                         -- DECIMAL
    PROG_EMPTY_THRESH   => FIFO_DEPTH / 10,                           -- DECIMAL
    PROG_FULL_THRESH    => 9 * FIFO_DEPTH / 10,                       -- DECIMAL
    RD_DATA_COUNT_WIDTH => integer(ceil(log2(real(FIFO_DEPTH)))) + 1, -- DECIMAL
    READ_DATA_WIDTH     => fifo_dout'length,                          -- DECIMAL
    READ_MODE           => "fwft",                                    -- String
    RELATED_CLOCKS      => 0,                                         -- DECIMAL
    SIM_ASSERT_CHK      => 0,                                         -- DECIMAL
    USE_ADV_FEATURES    => "0000",                                    -- String
    WAKEUP_TIME         => 0,                                         -- DECIMAL
    WRITE_DATA_WIDTH    => fifo_din'length,                           -- DECIMAL
    WR_DATA_COUNT_WIDTH => integer(ceil(log2(real(FIFO_DEPTH)))) + 1  -- DECIMAL
  )
  port map(
    almost_empty  => open,
    almost_full   => open,
    data_valid    => open,
    dbiterr       => open,
    dout          => fifo_dout,
    empty         => fifo_empty,
    full          => open,
    overflow      => open,
    prog_empty    => open,
    prog_full     => open,
    rd_data_count => open,
    rd_rst_busy   => open,
    sbiterr       => open,
    underflow     => open,
    wr_ack        => open,
    wr_data_count => open,
    wr_rst_busy   => open,
    din           => fifo_din,
    injectdbiterr => '0',
    injectsbiterr => '0',
    rd_clk        => lcl_clk,
    rd_en         => fifo_rd,
    rst           => fifo_rst(0),
    sleep         => '0',
    wr_clk        => gmii_rx_clk,
    wr_en         => fifo_wr
  );

  fifo_rd_proc : process (lcl_clk) is
  begin
    if rising_edge(lcl_clk) then
      -- initialize --
      fifo_rd   <= '0';
      sof_out   <= '0';
      eof_out   <= '0';
      valid_out <= '0';
      data_out  <= (others => '0');

      if fifo_empty /= '0' then
        fifo_rd   <= '1';
        sof_out   <= fifo_dout(fifo_dout'left);
        eof_out   <= fifo_dout(fifo_dout'left - 1);
        valid_out <= fifo_dout(fifo_dout'left - 2);
        data_out  <= fifo_dout(data_out'length - 1 downto 0);
      end if;
    end if;
  end process fifo_rd_proc;
end architecture rtl;