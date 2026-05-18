library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

entity dot_product is
  generic (
    G_A_BITS     : natural;
    G_B_BITS     : natural;
    G_O_BITS     : natural;
    G_A_ACCURACY : natural;
    G_B_ACCURACY : natural;
    G_O_ACCURACY : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_a_x_i   : in    sfixed(G_A_BITS - 1 downto -G_A_ACCURACY);
    s_a_y_i   : in    sfixed(G_A_BITS - 1 downto -G_A_ACCURACY);
    s_b_x_i   : in    sfixed(G_B_BITS - 1 downto -G_B_ACCURACY);
    s_b_y_i   : in    sfixed(G_B_BITS - 1 downto -G_B_ACCURACY);

    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_res_o   : out   sfixed(G_O_BITS - 1 downto -G_O_ACCURACY)
  );
end entity dot_product;

architecture synthesis of dot_product is

  signal stage1_valid : std_logic;
  signal s_a_x : sfixed(G_A_BITS - 1 downto -G_A_ACCURACY);
  signal s_a_y : sfixed(G_A_BITS - 1 downto -G_A_ACCURACY);
  signal s_b_x : sfixed(G_B_BITS - 1 downto -G_B_ACCURACY);
  signal s_b_y : sfixed(G_B_BITS - 1 downto -G_B_ACCURACY);

  signal stage2_valid : std_logic;
  signal x2   : sfixed(G_O_BITS - 1 downto -G_O_ACCURACY);
  signal y2   : sfixed(G_O_BITS - 1 downto -G_O_ACCURACY);

begin

  s_ready_o <= m_ready_i or not m_valid_o;

  stage1_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_ready_o = '1' then
        stage1_valid <= '0';
      end if;

      s_a_x        <= s_a_x_i;
      s_a_y        <= s_a_y_i;
      s_b_x        <= s_b_x_i;
      s_b_y        <= s_b_y_i;

      if s_valid_i = '1' and s_ready_o = '1' then
        stage1_valid <= '1';
      end if;

      if rst_i = '1' then
        stage1_valid <= '0';
      end if;
    end if;
  end process stage1_proc;

  stage2_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      x2 <= resize(s_a_x * s_b_x, x2,
                   round_style    => fixed_truncate,
                   overflow_style => fixed_wrap);

      y2 <= resize(s_a_y * s_b_y, y2,
                   round_style    => fixed_truncate,
                   overflow_style => fixed_wrap);

      stage2_valid <= stage1_valid;
    end if;
  end process stage2_proc;

  adder_inst : entity work.adder
    generic map (
      G_REG      => true,
      G_BITS     => G_O_BITS,
      G_ACCURACY => G_O_ACCURACY
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => open,
      s_valid_i => stage2_valid,
      s_a_i     => x2,
      s_b_i     => y2,
      m_ready_i => m_ready_i,
      m_valid_o => m_valid_o,
      m_res_o   => m_res_o
    ); -- adder_inst : entity work.adder

end architecture synthesis;

