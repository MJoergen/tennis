-- ----------------------------------------------------------------------------
-- Title      : Main FPGA
-- Project    : XENTA, RCU, PCB1036 Board
-- ----------------------------------------------------------------------------
-- File       : cmd.vhd
-- Author     : Michael Jørgensen
-- Company    : Weibel Scientific
-- Created    : 2025-05-19
-- Platform   : AMD Artix 7
-- ----------------------------------------------------------------------------
-- Description: Simple command line interpreter
-- Data is left justified.
-- Commands available:
-- H               : Display help text
-- W AAAA DDDDDDDD : Write <DDDD> to <AAAA>
-- R AAAA          : Read from <AAAA>
-- K               : Read base address of I2C controller
-- K AAAA          : Set base address of KSZ controller
-- KSZ RR          : Read from KSZ address <RR>
-- KSZ RR VVVV     : Write <VVVV> to KSZ address <RR>
-- I               : Read base address of I2C controller
-- I AAAA          : Set base address of I2C controller
-- INA DD RR       : Read from I2C device <DD> address <RR>
-- INA DD RR VVVV  : Write <VVVV> to I2C device <DD> address <RR>
--
-- The output is a Wishbone Master interface 32-bit (Revision B.4)
-- https://cdn.opencores.org/downloads/wbspec_b4.pdf
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity cmd is
  generic (
    G_CLOCK_KHZ  : natural;
    G_NAME_STR   : string;
    G_ADDR_SIZE  : natural;
    G_DATA_BYTES : natural
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;

    -- Line buffer
    s_axip_rx_ready_o : out   std_logic;
    s_axip_rx_valid_i : in    std_logic;
    s_axip_rx_data_i  : in    std_logic_vector(8 * G_DATA_BYTES - 1 downto 0);
    s_axip_rx_bytes_i : in    natural range 0 to G_DATA_BYTES;
    m_axip_tx_ready_i : in    std_logic;
    m_axip_tx_valid_o : out   std_logic;
    m_axip_tx_data_o  : out   std_logic_vector(8 * G_DATA_BYTES - 1 downto 0);
    m_axip_tx_bytes_o : out   natural range 0 to G_DATA_BYTES;

    -- Wishbone bus Master interface
    wbus_cyc_o        : out   std_logic;                                  -- Valid bus cycle
    wbus_stall_i      : in    std_logic;
    wbus_stb_o        : out   std_logic;                                  -- Strobe signals / core select signal
    wbus_addr_o       : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0); -- lower address bits
    wbus_we_o         : out   std_logic;                                  -- Write enable
    wbus_wrdat_o      : out   std_logic_vector(31 downto 0);              -- Write Databus
    wbus_ack_i        : in    std_logic;                                  -- Bus cycle acknowledge
    wbus_rddat_i      : in    std_logic_vector(31 downto 0)               -- Read Databus
  );
end entity cmd;

architecture synthesis of cmd is

  signal busy            : std_logic;
  signal timeout         : std_logic;
  signal wr_addr         : std_logic_vector(15 downto 0);
  signal wr_data         : std_logic_vector(31 downto 0);
  signal wr_en           : std_logic;
  signal wr_ack          : std_logic;
  signal rd_addr         : std_logic_vector(15 downto 0);
  signal rd_en           : std_logic;
  signal rd_data         : std_logic_vector(31 downto 0);
  signal rd_ack          : std_logic;
  signal i_rd_en         : std_logic;
  signal i_rd_addr       : std_logic_vector(15 downto 0);
  signal i_rd_ack        : std_logic;
  signal i_wr_addr       : std_logic_vector(15 downto 0);
  signal i_wr_en         : std_logic;
  signal i_wr_ack        : std_logic;
  signal ina_rd_device   : std_logic_vector(7 downto 0);
  signal ina_rd_register : std_logic_vector(7 downto 0);
  signal ina_rd_en       : std_logic;
  signal ina_rd_data     : std_logic_vector(15 downto 0);
  signal ina_rd_ack      : std_logic;
  signal ina_wr_device   : std_logic_vector(7 downto 0);
  signal ina_wr_register : std_logic_vector(7 downto 0);
  signal ina_wr_data     : std_logic_vector(15 downto 0);
  signal ina_wr_en       : std_logic;
  signal ina_wr_ack      : std_logic;
  signal k_rd_en         : std_logic;
  signal k_rd_addr       : std_logic_vector(15 downto 0);
  signal k_rd_ack        : std_logic;
  signal k_wr_addr       : std_logic_vector(15 downto 0);
  signal k_wr_en         : std_logic;
  signal k_wr_ack        : std_logic;
  signal ksz_rd_register : std_logic_vector(15 downto 0);
  signal ksz_rd_en       : std_logic;
  signal ksz_rd_data     : std_logic_vector(15 downto 0);
  signal ksz_rd_ack      : std_logic;
  signal ksz_wr_register : std_logic_vector(15 downto 0);
  signal ksz_wr_data     : std_logic_vector(15 downto 0);
  signal ksz_wr_en       : std_logic;
  signal ksz_wr_ack      : std_logic;

  signal axip_rx_ready : std_logic;
  signal axip_rx_valid : std_logic;
  signal axip_rx_data  : std_logic_vector(8 * G_DATA_BYTES - 1 downto 0);
  signal axip_rx_bytes : natural range 0 to G_DATA_BYTES;

begin

  ------------------------------------------------
  -- Strip away trailing CR / LF from input
  ------------------------------------------------

  s_axip_rx_ready_o <= axip_rx_ready and not axip_rx_valid;

  find_end_proc : process (clk_i)
    --

    pure function find_end (
      arg : std_logic_vector;
      len : natural
    ) return natural is
      variable res_v  : natural;
      variable byte_v : std_logic_vector(7 downto 0);
    begin
      for i in 0 to G_DATA_BYTES - 1 loop
        if i = len then
          return i;
        end if;

        byte_v :=  arg(8 * (G_DATA_BYTES - i) - 1 downto 8 * (G_DATA_BYTES - i) - 8);

        if byte_v = X"0D" or byte_v = X"0A" then
          return i;
        end if;
      end loop;

      return len;
    end function find_end;

  begin
    if rising_edge(clk_i) then
      if axip_rx_ready = '1' then
        axip_rx_valid <= '0';
      end if;

      if s_axip_rx_valid_i = '1' and s_axip_rx_ready_o = '1' then
        axip_rx_data  <= s_axip_rx_data_i;
        axip_rx_bytes <= find_end(s_axip_rx_data_i, s_axip_rx_bytes_i);
        axip_rx_valid <= '1';
      end if;

      if rst_i = '1' then
        axip_rx_valid <= '0';
      end if;
    end if;
  end process find_end_proc;


  ------------------------------------------------
  -- Parse input string
  ------------------------------------------------

  parser_inst : entity work.parser
    generic map (
      G_NAME_STR   => G_NAME_STR,
      G_DATA_BYTES => G_DATA_BYTES
    )
    port map (
      clk_i             => clk_i,
      rst_i             => rst_i,
      s_axip_rx_ready_o => axip_rx_ready,
      s_axip_rx_valid_i => axip_rx_valid,
      s_axip_rx_data_i  => axip_rx_data,
      s_axip_rx_bytes_i => axip_rx_bytes,
      m_axip_tx_ready_i => m_axip_tx_ready_i,
      m_axip_tx_valid_o => m_axip_tx_valid_o,
      m_axip_tx_data_o  => m_axip_tx_data_o,
      m_axip_tx_bytes_o => m_axip_tx_bytes_o,
      busy_i            => busy,
      timeout_i         => timeout,
      wr_addr_o         => wr_addr,
      wr_data_o         => wr_data,
      wr_en_o           => wr_en,
      wr_ack_i          => wr_ack,
      rd_addr_o         => rd_addr,
      rd_en_o           => rd_en,
      rd_data_i         => rd_data,
      rd_ack_i          => rd_ack,
      i_rd_en_o         => i_rd_en,
      i_rd_addr_i       => i_rd_addr,
      i_rd_ack_i        => i_rd_ack,
      i_wr_addr_o       => i_wr_addr,
      i_wr_en_o         => i_wr_en,
      i_wr_ack_i        => i_wr_ack,
      ina_rd_device_o   => ina_rd_device,
      ina_rd_register_o => ina_rd_register,
      ina_rd_en_o       => ina_rd_en,
      ina_rd_data_i     => ina_rd_data,
      ina_rd_ack_i      => ina_rd_ack,
      ina_wr_device_o   => ina_wr_device,
      ina_wr_register_o => ina_wr_register,
      ina_wr_data_o     => ina_wr_data,
      ina_wr_en_o       => ina_wr_en,
      ina_wr_ack_i      => ina_wr_ack,
      k_rd_en_o         => k_rd_en,
      k_rd_addr_i       => k_rd_addr,
      k_rd_ack_i        => k_rd_ack,
      k_wr_addr_o       => k_wr_addr,
      k_wr_en_o         => k_wr_en,
      k_wr_ack_i        => k_wr_ack,
      ksz_rd_register_o => ksz_rd_register,
      ksz_rd_en_o       => ksz_rd_en,
      ksz_rd_data_i     => ksz_rd_data,
      ksz_rd_ack_i      => ksz_rd_ack,
      ksz_wr_register_o => ksz_wr_register,
      ksz_wr_data_o     => ksz_wr_data,
      ksz_wr_en_o       => ksz_wr_en,
      ksz_wr_ack_i      => ksz_wr_ack
    ); -- parser_inst : entity work.parser


  ------------------------------------------------
  -- Convert to WBUS commands
  ------------------------------------------------

  dispatcher_inst : entity work.dispatcher
    generic map (
      G_CLOCK_KHZ => G_CLOCK_KHZ,
      G_ADDR_SIZE => G_ADDR_SIZE
    )
    port map (
      clk_i             => clk_i,
      rst_i             => rst_i,
      busy_o            => busy,
      timeout_o         => timeout,
      wr_addr_i         => wr_addr,
      wr_data_i         => wr_data,
      wr_en_i           => wr_en,
      wr_ack_o          => wr_ack,
      rd_addr_i         => rd_addr,
      rd_en_i           => rd_en,
      rd_data_o         => rd_data,
      rd_ack_o          => rd_ack,
      i_rd_en_i         => i_rd_en,
      i_rd_addr_o       => i_rd_addr,
      i_rd_ack_o        => i_rd_ack,
      i_wr_addr_i       => i_wr_addr,
      i_wr_en_i         => i_wr_en,
      i_wr_ack_o        => i_wr_ack,
      ina_rd_device_i   => ina_rd_device,
      ina_rd_register_i => ina_rd_register,
      ina_rd_en_i       => ina_rd_en,
      ina_rd_data_o     => ina_rd_data,
      ina_rd_ack_o      => ina_rd_ack,
      ina_wr_device_i   => ina_wr_device,
      ina_wr_register_i => ina_wr_register,
      ina_wr_data_i     => ina_wr_data,
      ina_wr_en_i       => ina_wr_en,
      ina_wr_ack_o      => ina_wr_ack,
      k_rd_en_i         => k_rd_en,
      k_rd_addr_o       => k_rd_addr,
      k_rd_ack_o        => k_rd_ack,
      k_wr_addr_i       => k_wr_addr,
      k_wr_en_i         => k_wr_en,
      k_wr_ack_o        => k_wr_ack,
      ksz_rd_register_i => ksz_rd_register,
      ksz_rd_en_i       => ksz_rd_en,
      ksz_rd_data_o     => ksz_rd_data,
      ksz_rd_ack_o      => ksz_rd_ack,
      ksz_wr_register_i => ksz_wr_register,
      ksz_wr_data_i     => ksz_wr_data,
      ksz_wr_en_i       => ksz_wr_en,
      ksz_wr_ack_o      => ksz_wr_ack,
      wbus_cyc_o        => wbus_cyc_o,
      wbus_stall_i      => wbus_stall_i,
      wbus_stb_o        => wbus_stb_o,
      wbus_addr_o       => wbus_addr_o,
      wbus_we_o         => wbus_we_o,
      wbus_wrdat_o      => wbus_wrdat_o,
      wbus_ack_i        => wbus_ack_i,
      wbus_rddat_i      => wbus_rddat_i
    ); -- dispatcher_inst : entity work.dispatcher

end architecture synthesis;

