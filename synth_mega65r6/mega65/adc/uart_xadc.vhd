library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.wbus_pkg.slv32_array_type;

entity uart_xadc is
  port (
    clk_i      : in    std_logic;
    rst_i      : in    std_logic;
    uart_rxd_i : in    std_logic;
    uart_txd_o : out   std_logic;
    vp_i       : in    std_logic;
    vn_i       : in    std_logic
  );
end entity uart_xadc;

architecture synthesis of uart_xadc is

  constant C_NUM_SLAVES      : natural := 2;
  constant C_SLAVE_ADDR_SIZE : natural := 12;

  signal   wbus_uart_cyc   : std_logic;
  signal   wbus_uart_stall : std_logic;
  signal   wbus_uart_stb   : std_logic;
  signal   wbus_uart_addr  : std_logic_vector(15 downto 0);
  signal   wbus_uart_we    : std_logic;
  signal   wbus_uart_wrdat : std_logic_vector(31 downto 0);
  signal   wbus_uart_ack   : std_logic;
  signal   wbus_uart_rddat : std_logic_vector(31 downto 0);

  signal   wbus_map_rst   : std_logic_vector(C_NUM_SLAVES - 1 downto 0);
  signal   wbus_map_cyc   : std_logic;
  signal   wbus_map_stall : std_logic_vector(C_NUM_SLAVES - 1 downto 0);
  signal   wbus_map_stb   : std_logic_vector(C_NUM_SLAVES - 1 downto 0);
  signal   wbus_map_addr  : std_logic_vector(C_SLAVE_ADDR_SIZE - 1 downto 0);
  signal   wbus_map_we    : std_logic;
  signal   wbus_map_wrdat : std_logic_vector(31 downto 0);
  signal   wbus_map_ack   : std_logic_vector(C_NUM_SLAVES - 1 downto 0);
  signal   wbus_map_rddat : slv32_array_type(C_NUM_SLAVES - 1 downto 0);

  signal   wbus_stat_cyc   : std_logic;
  signal   wbus_stat_stall : std_logic;
  signal   wbus_stat_stb   : std_logic;
  signal   wbus_stat_addr  : std_logic_vector(11 downto 0);
  signal   wbus_stat_we    : std_logic;
  signal   wbus_stat_wrdat : std_logic_vector(31 downto 0);
  signal   wbus_stat_ack   : std_logic;
  signal   wbus_stat_rddat : std_logic_vector(31 downto 0);

  signal   wbus_arb_cyc   : std_logic;
  signal   wbus_arb_stall : std_logic;
  signal   wbus_arb_stb   : std_logic;
  signal   wbus_arb_addr  : std_logic_vector(11 downto 0);
  signal   wbus_arb_we    : std_logic;
  signal   wbus_arb_wrdat : std_logic_vector(31 downto 0);
  signal   wbus_arb_ack   : std_logic;
  signal   wbus_arb_rddat : std_logic_vector(31 downto 0);

begin

  -------------------------------
  -- Convert UART to WBUS
  -------------------------------

  uart_wbus_inst : entity work.uart_wbus
    generic map (
      G_NAME_STR      => "ADC",
      G_CLOCK_KHZ     => 148_500,
      G_UART_BAUDRATE => 115_200,
      G_ADDR_SIZE     => 16
    )
    port map (
      clk_i        => clk_i,
      rst_i        => rst_i,
      uart_rxd_i   => uart_rxd_i,
      uart_txd_o   => uart_txd_o,
      wbus_cyc_o   => wbus_uart_cyc,
      wbus_stall_i => wbus_uart_stall,
      wbus_stb_o   => wbus_uart_stb,
      wbus_addr_o  => wbus_uart_addr,
      wbus_we_o    => wbus_uart_we,
      wbus_wrdat_o => wbus_uart_wrdat,
      wbus_ack_i   => wbus_uart_ack,
      wbus_rddat_i => wbus_uart_rddat
    ); -- uart_wbus_inst : entity work.uart_wbus


  -------------------------------
  -- Instantiate WBUS mapper
  -------------------------------

  wbus_mapper_inst : entity work.wbus_mapper
    generic map (
      G_TIMEOUT          => 4000,
      G_NUM_SLAVES       => C_NUM_SLAVES,
      G_MASTER_ADDR_SIZE => 16,
      G_SLAVE_ADDR_SIZE  => C_SLAVE_ADDR_SIZE
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_cyc_i   => wbus_uart_cyc,
      s_stall_o => wbus_uart_stall,
      s_stb_i   => wbus_uart_stb,
      s_addr_i  => wbus_uart_addr,
      s_we_i    => wbus_uart_we,
      s_wrdat_i => wbus_uart_wrdat,
      s_ack_o   => wbus_uart_ack,
      s_rddat_o => wbus_uart_rddat,
      m_rst_o   => wbus_map_rst,
      m_cyc_o   => wbus_map_cyc,
      m_stall_i => wbus_map_stall,
      m_stb_o   => wbus_map_stb,
      m_addr_o  => wbus_map_addr,
      m_we_o    => wbus_map_we,
      m_wrdat_o => wbus_map_wrdat,
      m_ack_i   => wbus_map_ack,
      m_rddat_i => wbus_map_rddat
    );


  -------------------------------
  -- WBUS 0 : Statistics module
  -------------------------------

  wbus_stats_inst : entity work.wbus_stats
    port map (
      clk_i          => clk_i,
      rst_i          => wbus_map_rst(0),
      s_wbus_cyc_i   => wbus_map_cyc,
      s_wbus_stall_o => wbus_map_stall(0),
      s_wbus_stb_i   => wbus_map_stb(0),
      s_wbus_addr_i  => wbus_map_addr,
      s_wbus_we_i    => wbus_map_we,
      s_wbus_wrdat_i => wbus_map_wrdat,
      s_wbus_ack_o   => wbus_map_ack(0),
      s_wbus_rddat_o => wbus_map_rddat(0),
      m_wbus_cyc_o   => wbus_stat_cyc,
      m_wbus_stall_i => wbus_stat_stall,
      m_wbus_stb_o   => wbus_stat_stb,
      m_wbus_addr_o  => wbus_stat_addr,
      m_wbus_we_o    => wbus_stat_we,
      m_wbus_wrdat_o => wbus_stat_wrdat,
      m_wbus_ack_i   => wbus_stat_ack,
      m_wbus_rddat_i => wbus_stat_rddat
    ); -- wbus_stats_inst : entity work.wbus_stats


  -------------------------------
  -- WBUS 1 : XADC module
  -------------------------------

  wbus_arbiter_inst : entity work.wbus_arbiter
    generic map (
      G_ADDR_SIZE => C_SLAVE_ADDR_SIZE,
      G_DATA_SIZE => 32
    )
    port map (
      clk_i      => clk_i,
      rst_i      => wbus_map_rst(1),
      s0_cyc_i   => wbus_map_cyc,
      s0_stall_o => wbus_map_stall(1),
      s0_stb_i   => wbus_map_stb(1),
      s0_addr_i  => wbus_map_addr,
      s0_we_i    => wbus_map_we,
      s0_wrdat_i => wbus_map_wrdat,
      s0_ack_o   => wbus_map_ack(1),
      s0_rddat_o => wbus_map_rddat(1),
      s1_cyc_i   => wbus_stat_cyc,
      s1_stall_o => wbus_stat_stall,
      s1_stb_i   => wbus_stat_stb,
      s1_addr_i  => wbus_stat_addr,
      s1_we_i    => wbus_stat_we,
      s1_wrdat_i => wbus_stat_wrdat,
      s1_ack_o   => wbus_stat_ack,
      s1_rddat_o => wbus_stat_rddat,
      m_cyc_o    => wbus_arb_cyc,
      m_stall_i  => wbus_arb_stall,
      m_stb_o    => wbus_arb_stb,
      m_addr_o   => wbus_arb_addr,
      m_we_o     => wbus_arb_we,
      m_wrdat_o  => wbus_arb_wrdat,
      m_ack_i    => wbus_arb_ack,
      m_rddat_i  => wbus_arb_rddat
    );


  -------------------------------
  -- Instantiate XADC module
  -------------------------------

  my_xadc_inst : entity work.my_xadc
    generic map (
      G_ADDR_SIZE => C_SLAVE_ADDR_SIZE
    )
    port map (
      clk_i        => clk_i,
      rst_i        => rst_i,
      wbus_cyc_i   => wbus_arb_cyc,
      wbus_stall_o => wbus_arb_stall,
      wbus_stb_i   => wbus_arb_stb,
      wbus_addr_i  => wbus_arb_addr,
      wbus_we_i    => wbus_arb_we,
      wbus_wrdat_i => wbus_arb_wrdat,
      wbus_ack_o   => wbus_arb_ack,
      wbus_rddat_o => wbus_arb_rddat,
      vp_i         => vp_i,
      vn_i         => vn_i
    ); -- my_xadc_inst : entity work.my_xadc

end architecture synthesis;

