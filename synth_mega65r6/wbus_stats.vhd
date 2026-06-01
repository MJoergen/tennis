library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity wbus_stats is
  port (
    clk_i          : in    std_logic;
    rst_i          : in    std_logic;
    s_wbus_cyc_i   : in    std_logic;
    s_wbus_stall_o : out   std_logic;
    s_wbus_stb_i   : in    std_logic;
    s_wbus_addr_i  : in    std_logic_vector(15 downto 0);
    s_wbus_we_i    : in    std_logic;
    s_wbus_wrdat_i : in    std_logic_vector(31 downto 0);
    s_wbus_ack_o   : out   std_logic;
    s_wbus_rddat_o : out   std_logic_vector(31 downto 0);

    m_wbus_cyc_o   : out   std_logic;
    m_wbus_stall_i : in    std_logic;
    m_wbus_stb_o   : out   std_logic;
    m_wbus_addr_o  : out   std_logic_vector(15 downto 0);
    m_wbus_we_o    : out   std_logic;
    m_wbus_wrdat_o : out   std_logic_vector(31 downto 0);
    m_wbus_ack_i   : in    std_logic;
    m_wbus_rddat_i : in    std_logic_vector(31 downto 0)
  );
end entity wbus_stats;

architecture synthesis of wbus_stats is

  type     fsm_type is (IDLE_ST, BUSY_ST);
  signal   state : fsm_type                            := IDLE_ST;

  signal   stats_s_ready     : std_logic;
  signal   stats_s_valid     : std_logic;
  signal   stats_s_data      : std_logic_vector(31 downto 0);
  signal   stats_m_ready     : std_logic;
  signal   stats_m_valid     : std_logic;
  signal   stats_m_min_val   : std_logic_vector(31 downto 0);
  signal   stats_m_max_val   : std_logic_vector(31 downto 0);
  signal   stats_m_mean_val  : std_logic_vector(31 downto 0);
  signal   stats_m_mean_diff : std_logic_vector(31 downto 0);

  constant C_WBUS_ADDR : std_logic_vector(15 downto 0) := X"0000";

begin

  s_wbus_stall_o <= '0';

  wbus_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      stats_m_ready <= '0';
      s_wbus_ack_o  <= '0';
      if s_wbus_cyc_i = '1' and s_wbus_stb_i = '1' and s_wbus_we_i = '0' then
        s_wbus_rddat_o <= (others => '0');
        s_wbus_ack_o   <= '1';

        if stats_m_valid = '1' then

          case s_wbus_addr_i is

            when X"0000" =>
              s_wbus_rddat_o <= stats_m_min_val;

            when X"0004" =>
              s_wbus_rddat_o <= stats_m_max_val;

            when X"0008" =>
              s_wbus_rddat_o <= stats_m_mean_val;

            when X"000C" =>
              s_wbus_rddat_o <= stats_m_mean_diff;

            when others =>
              null;

          end case;

        end if;
      end if;

      if s_wbus_cyc_i = '1' and s_wbus_stb_i = '1' and s_wbus_we_i = '1' then
        stats_m_ready <= '1';
      end if;

      if rst_i = '1' then
        stats_m_ready <= '1';
      end if;
    end if;
  end process wbus_proc;

  stats_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_wbus_stall_i = '0' then
        m_wbus_stb_o <= '0';
      end if;

      if m_wbus_ack_i = '1' then
        m_wbus_cyc_o <= '0';
      end if;

      if stats_s_ready = '1' then
        stats_s_valid <= '0';
      end if;

      case state is

        when IDLE_ST =>
          if stats_s_ready = '1' then
            m_wbus_cyc_o  <= '1';
            m_wbus_stb_o  <= '1';
            m_wbus_addr_o <= C_WBUS_ADDR;
            m_wbus_we_o   <= '0';
            state         <= BUSY_ST;
          end if;

        when BUSY_ST =>
          if m_wbus_ack_i = '1' then
            stats_s_data  <= m_wbus_rddat_i;
            stats_s_valid <= '1';
            state         <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        m_wbus_cyc_o  <= '0';
        m_wbus_stb_o  <= '0';
        m_wbus_we_o   <= '0';
        m_wbus_addr_o <= (others => '0');
        state         <= IDLE_ST;
        stats_s_valid <= '0';
      end if;
    end if;
  end process stats_proc;

  stats_inst : entity work.stats
    generic map (
      G_DATA_SIZE => 32,
      G_ACCURACY  => 4
    )
    port map (
      clk_i         => clk_i,
      rst_i         => rst_i,
      s_ready_o     => stats_s_ready,
      s_valid_i     => stats_s_valid,
      s_data_i      => stats_s_data,
      m_ready_i     => stats_m_ready,
      m_valid_o     => stats_m_valid,
      m_min_val_o   => stats_m_min_val,
      m_max_val_o   => stats_m_max_val,
      m_mean_val_o  => stats_m_mean_val,
      m_mean_diff_o => stats_m_mean_diff
    ); -- stats_inst : entity work.stats

end architecture synthesis;

