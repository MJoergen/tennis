-- ----------------------------------------------------------------------------
-- Title      : Main FPGA
-- Project    : XENTA, RCU, PCB1036 Board
-- ----------------------------------------------------------------------------
-- File       : uart_wbus.vhd
-- Author     : Michael Jørgensen
-- Company    : Weibel Scientific
-- Created    : 2025-05-19
-- Platform   : AMD Artix 7
-- ----------------------------------------------------------------------------
-- Description: USB to Wishbone converter
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity uart_wbus is
  generic (
    G_NAME_STR      : string;
    G_CLOCK_KHZ     : natural;
    G_UART_BAUDRATE : natural := 115_200;
    G_ADDR_SIZE     : natural := 10
  );
  port (
    clk_i        : in    std_logic;
    rst_i        : in    std_logic;

    -- UART Control
    uart_rxd_i   : in    std_logic;
    uart_txd_o   : out   std_logic;

    -- Wishbone bus Master interface
    wbus_cyc_o   : out   std_logic;                                  -- Valid bus cycle
    wbus_stall_i : in    std_logic;
    wbus_stb_o   : out   std_logic;                                  -- Strobe signals / core select signal
    wbus_addr_o  : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0); -- lower address bits
    wbus_we_o    : out   std_logic;                                  -- Write enable
    wbus_wrdat_o : out   std_logic_vector(31 downto 0);              -- Write Databus
    wbus_ack_i   : in    std_logic;                                  -- Bus cycle acknowledge
    wbus_rddat_i : in    std_logic_vector(31 downto 0)               -- Read Databus
  );
end entity uart_wbus;

architecture synthesis of uart_wbus is

  constant C_DATA_BYTES : natural := 20;

  signal   axis_rx_valid : std_logic;
  signal   axis_rx_ready : std_logic;
  signal   axis_rx_data  : std_logic_vector(7 downto 0);
  signal   axis_tx_ready : std_logic;
  signal   axis_tx_valid : std_logic;
  signal   axis_tx_data  : std_logic_vector(7 downto 0);

  signal   axip_rx_ready : std_logic;
  signal   axip_rx_valid : std_logic;
  signal   axip_rx_data  : std_logic_vector(8 * C_DATA_BYTES - 1 downto 0);
  signal   axip_rx_bytes : natural range 0 to C_DATA_BYTES;
  signal   axip_tx_ready : std_logic;
  signal   axip_tx_valid : std_logic;
  signal   axip_tx_data  : std_logic_vector(8 * C_DATA_BYTES - 1 downto 0);
  signal   axip_tx_bytes : natural range 0 to C_DATA_BYTES;

begin

  uart_serdes_inst : entity work.uart_serdes
    generic map (
      G_DIVISOR => G_CLOCK_KHZ * 1000 / G_UART_BAUDRATE
    )
    port map (
      clk_i      => clk_i,
      rst_i      => rst_i,
      uart_tx_o  => uart_txd_o,
      uart_rx_i  => uart_rxd_i,
      rx_valid_o => axis_rx_valid,
      rx_ready_i => axis_rx_ready,
      rx_data_o  => axis_rx_data,
      tx_valid_i => axis_tx_valid,
      tx_ready_o => axis_tx_ready,
      tx_data_i  => axis_tx_data
    ); -- uart_serdes_inst : entity work.uart_serdes

  line_buffer_inst : entity work.line_buffer
    generic map (
      G_LOCAL_ECHO => true,
      G_DATA_BYTES => C_DATA_BYTES
    )
    port map (
      clk_i             => clk_i,
      rst_i             => rst_i,
      s_axis_rx_ready_o => axis_rx_ready,
      s_axis_rx_valid_i => axis_rx_valid,
      s_axis_rx_data_i  => axis_rx_data,
      m_axis_tx_ready_i => axis_tx_ready,
      m_axis_tx_valid_o => axis_tx_valid,
      m_axis_tx_data_o  => axis_tx_data,
      m_axip_rx_ready_i => axip_rx_ready,
      m_axip_rx_valid_o => axip_rx_valid,
      m_axip_rx_data_o  => axip_rx_data,
      m_axip_rx_bytes_o => axip_rx_bytes,
      s_axip_tx_ready_o => axip_tx_ready,
      s_axip_tx_valid_i => axip_tx_valid,
      s_axip_tx_data_i  => axip_tx_data,
      s_axip_tx_bytes_i => axip_tx_bytes
    ); -- line_buffer_inst : entity work.line_buffer

  cmd_inst : entity work.cmd
    generic map (
      G_CLOCK_KHZ  => G_CLOCK_KHZ,
      G_NAME_STR   => G_NAME_STR,
      G_ADDR_SIZE  => G_ADDR_SIZE,
      G_DATA_BYTES => C_DATA_BYTES
    )
    port map (
      clk_i             => clk_i,
      rst_i             => rst_i,
      s_axip_rx_ready_o => axip_rx_ready,
      s_axip_rx_valid_i => axip_rx_valid,
      s_axip_rx_data_i  => axip_rx_data,
      s_axip_rx_bytes_i => axip_rx_bytes,
      m_axip_tx_ready_i => axip_tx_ready,
      m_axip_tx_valid_o => axip_tx_valid,
      m_axip_tx_data_o  => axip_tx_data,
      m_axip_tx_bytes_o => axip_tx_bytes,
      wbus_cyc_o        => wbus_cyc_o,
      wbus_stall_i      => wbus_stall_i,
      wbus_stb_o        => wbus_stb_o,
      wbus_addr_o       => wbus_addr_o,
      wbus_we_o         => wbus_we_o,
      wbus_wrdat_o      => wbus_wrdat_o,
      wbus_ack_i        => wbus_ack_i,
      wbus_rddat_i      => wbus_rddat_i
    ); -- cmd_inst : entity work.cmd

end architecture synthesis;

