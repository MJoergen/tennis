library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_stats is
end entity tb_stats;

architecture simulation of tb_stats is

  signal   running : std_logic                := '1';
  signal   clk     : std_logic                := '1';
  signal   rst     : std_logic                := '1';

  constant C_DATA_SIZE : natural              := 16;
  constant C_ACCURACY  : natural              := 4;

  signal   s_ready     : std_logic;
  signal   s_valid     : std_logic;
  signal   s_data      : std_logic_vector(C_DATA_SIZE - 1 downto 0);
  signal   m_ready     : std_logic;
  signal   m_valid     : std_logic;
  signal   m_min_val   : std_logic_vector(C_DATA_SIZE - 1 downto 0);
  signal   m_max_val   : std_logic_vector(C_DATA_SIZE - 1 downto 0);
  signal   m_mean_val  : std_logic_vector(C_DATA_SIZE - 1 downto 0);
  signal   m_mean_diff : std_logic_vector(C_DATA_SIZE - 1 downto 0);

  subtype  VAL_TYPE is std_logic_vector(C_DATA_SIZE - 1 downto 0);

  type     val_vector_type is array (natural range <>) of VAL_TYPE;

  constant C_TEST_1 : val_vector_type(0 to 0) := (0 => X"1234");
  constant C_EXP_1  : val_vector_type(0 to 3) := (0 => X"1234", 1 => X"1234", 2 =>
    X"1234", 3 => X"0000");

  constant C_TEST_2 : val_vector_type(0 to 0) := (0 => X"9876");
  constant C_EXP_2  : val_vector_type(0 to 3) := (0 => X"9876", 1 => X"9876", 2 =>
    X"9876", 3 => X"0000");

  constant C_TEST_3 : val_vector_type(0 to 1) := (0 => X"9876", 1 => X"9856");
  constant C_EXP_3  : val_vector_type(0 to 3) := (0 => X"9856", 1 => X"9876", 2 =>
    X"9874", 3 => X"0002");

begin

  clk <= running and not clk after 5 ns; -- 100 MHz
  rst <= '1', '0' after 100 ns;

  stats_inst : entity work.stats
    generic map (
      G_DATA_SIZE => C_DATA_SIZE,
      G_ACCURACY  => C_ACCURACY
    )
    port map (
      clk_i         => clk,
      rst_i         => rst,
      s_ready_o     => s_ready,
      s_valid_i     => s_valid,
      s_data_i      => s_data,
      m_ready_i     => m_ready,
      m_valid_o     => m_valid,
      m_min_val_o   => m_min_val,
      m_max_val_o   => m_max_val,
      m_mean_val_o  => m_mean_val,
      m_mean_diff_o => m_mean_diff
    ); -- stats_inst : entity work.stats

  test_proc : process
    procedure verify (
      arg : val_vector_type;
      exp : val_vector_type
    ) is
    begin
      m_ready <= '0';
      for i in arg'range loop
        s_data  <= arg(i);
        s_valid <= '1';
        wait until rising_edge(clk);
        while s_ready /= '1' loop
          wait until rising_edge(clk);
        end loop;

        s_valid <= '0';
        wait until rising_edge(clk);
      end loop;

      assert m_valid = '1'
        report "Expected m_valid=1";
      assert m_min_val = exp(0)
        report "m_min_val expected " & to_hstring(exp(0)) & ", observed " & to_hstring(m_min_val);
      assert m_max_val = exp(1)
        report "m_max_val expected " & to_hstring(exp(1)) & ", observed " & to_hstring(m_max_val);
      assert m_mean_val = exp(2)
        report "m_mean_val expected " & to_hstring(exp(2)) & ", observed " & to_hstring(m_mean_val);
      assert m_mean_diff = exp(3)
        report "m_mean_diff expected " & to_hstring(exp(3)) & ", observed " & to_hstring(m_mean_diff);
      m_ready <= '1';
      wait until rising_edge(clk);
      m_ready <= '0';
      wait until rising_edge(clk);
      assert m_valid = '0';
    end procedure verify;

  begin
    s_valid <= '0';
    m_ready <= '1';
    wait until rst = '0';
    wait until rising_edge(clk);

    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);

    report "Test started";

    verify(C_TEST_1, C_EXP_1);
    verify(C_TEST_2, C_EXP_2);
    verify(C_TEST_3, C_EXP_3);

    report "Test finished";
    running <= '0';
    wait;
  end process test_proc;

end architecture simulation;

