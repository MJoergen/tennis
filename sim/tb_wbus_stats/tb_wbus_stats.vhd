library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_wbus_stats is
end entity tb_wbus_stats;

architecture simulation of tb_wbus_stats is

  signal running : std_logic := '1';
  signal clk     : std_logic := '1';
  signal rst     : std_logic := '1';

  signal s_wbus_cyc   : std_logic;
  signal s_wbus_stall : std_logic;
  signal s_wbus_stb   : std_logic;
  signal s_wbus_addr  : std_logic_vector(15 downto 0);
  signal s_wbus_we    : std_logic;
  signal s_wbus_wrdat : std_logic_vector(31 downto 0);
  signal s_wbus_ack   : std_logic;
  signal s_wbus_rddat : std_logic_vector(31 downto 0);

  signal m_wbus_cyc   : std_logic;
  signal m_wbus_stall : std_logic;
  signal m_wbus_stb   : std_logic;
  signal m_wbus_addr  : std_logic_vector(15 downto 0);
  signal m_wbus_we    : std_logic;
  signal m_wbus_wrdat : std_logic_vector(31 downto 0);
  signal m_wbus_ack   : std_logic;
  signal m_wbus_rddat : std_logic_vector(31 downto 0);

begin

  clk          <= running and not clk after 5 ns; -- 100 MHz
  rst          <= '1', '0' after 100 ns;

  test_proc : process
    --

    procedure write (
      addr : std_logic_vector;
      data : std_logic_vector
    ) is
    begin
      s_wbus_cyc   <= '1';
      s_wbus_stb   <= '1';
      s_wbus_we    <= '1';
      s_wbus_addr  <= addr;
      s_wbus_wrdat <= data;
      wait until rising_edge(clk);
      while s_wbus_stall /= '0' loop
        wait until rising_edge(clk);
      end loop;
      s_wbus_stb   <= '0';
      s_wbus_we    <= '0';
      s_wbus_addr  <= (others => '0');
      s_wbus_wrdat <= (others => '0');
      wait until rising_edge(clk);
      while s_wbus_ack /= '1' loop
        wait until rising_edge(clk);
      end loop;
      s_wbus_cyc <= '0';
      wait until rising_edge(clk);
    end procedure write;

    procedure verify (
      addr : std_logic_vector;
      data : std_logic_vector
    ) is
    begin
      s_wbus_cyc  <= '1';
      s_wbus_stb  <= '1';
      s_wbus_we   <= '0';
      s_wbus_addr <= addr;
      wait until rising_edge(clk);
      while s_wbus_stall /= '0' loop
        wait until rising_edge(clk);
      end loop;
      s_wbus_stb   <= '0';
      s_wbus_we    <= '0';
      s_wbus_addr  <= (others => '0');
      s_wbus_wrdat <= (others => '0');
      wait until rising_edge(clk);
      while s_wbus_ack /= '1' loop
        wait until rising_edge(clk);
      end loop;
      assert s_wbus_rddat = data
        report "addr " & to_hstring(addr) & " : read " & to_hstring(s_wbus_rddat) & ", expected " & to_hstring(data);
      s_wbus_cyc <= '0';
      wait until rising_edge(clk);
    end procedure verify;

  begin
    s_wbus_cyc   <= '0';
    s_wbus_stb   <= '0';
    s_wbus_we    <= '0';
    s_wbus_addr  <= (others => '0');
    s_wbus_wrdat <= (others => '0');
    wait until rst = '0';
    wait until rising_edge(clk);

    report "Test started";

    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);

    verify(X"0000", X"00001111");
    verify(X"0004", X"00001111");
    verify(X"0008", X"00001111");
    verify(X"000C", X"00000000");

    report "Test finished";
    running      <= '0';
    wait;
  end process test_proc;

  wbus_stats_inst : entity work.wbus_stats
    port map (
      clk_i          => clk,
      rst_i          => rst,
      s_wbus_cyc_i   => s_wbus_cyc,
      s_wbus_stall_o => s_wbus_stall,
      s_wbus_stb_i   => s_wbus_stb,
      s_wbus_addr_i  => s_wbus_addr,
      s_wbus_we_i    => s_wbus_we,
      s_wbus_wrdat_i => s_wbus_wrdat,
      s_wbus_ack_o   => s_wbus_ack,
      s_wbus_rddat_o => s_wbus_rddat,
      m_wbus_cyc_o   => m_wbus_cyc,
      m_wbus_stall_i => m_wbus_stall,
      m_wbus_stb_o   => m_wbus_stb,
      m_wbus_addr_o  => m_wbus_addr,
      m_wbus_we_o    => m_wbus_we,
      m_wbus_wrdat_o => m_wbus_wrdat,
      m_wbus_ack_i   => m_wbus_ack,
      m_wbus_rddat_i => m_wbus_rddat
    ); -- wbus_stats_inst : entity work.wbus_stats

  m_wbus_stall <= '0';

  wbus_proc : process (clk)
  begin
    if rising_edge(clk) then
      m_wbus_ack <= '0';
      if m_wbus_cyc = '1' and m_wbus_stb = '1' and m_wbus_we = '0' then
        m_wbus_rddat <= X"00001111";
        m_wbus_ack   <= '1';
      end if;
    end if;
  end process wbus_proc;

end architecture simulation;

