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

  signal x2 : sfixed(G_O_BITS - 1 downto -G_O_ACCURACY);
  signal y2 : sfixed(G_O_BITS - 1 downto -G_O_ACCURACY);

  signal xy2_valid : std_logic;

begin

  s_ready_o <= m_ready_i or not m_valid_o;

  res_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
      end if;

      if xy2_valid = '1' then
        xy2_valid <= '0';
        m_res_o   <= resize(x2 + y2, m_res_o,
                            round_style    => fixed_truncate,
                            overflow_style => fixed_wrap);
        m_valid_o <= '1';
      end if;

      if s_valid_i = '1' and s_ready_o = '1' then
        x2        <= resize(s_a_x_i * s_b_x_i, x2,
                            round_style    => fixed_truncate,
                            overflow_style => fixed_wrap);

        y2        <= resize(s_a_y_i * s_b_y_i, y2,
                            round_style    => fixed_truncate,
                            overflow_style => fixed_wrap);
        xy2_valid <= '1';
      end if;

      if rst_i = '1' then
        xy2_valid <= '0';
        m_valid_o <= '0';
      end if;
    end if;
  end process res_proc;

end architecture synthesis;

