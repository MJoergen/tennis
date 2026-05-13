library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

entity scalar_product is
  generic (
    G_A_BITS     : natural;
    G_A_ACCURACY : natural;
    G_B_BITS     : natural;
    G_B_ACCURACY : natural;
    G_O_BITS     : natural;
    G_O_ACCURACY : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_a_i     : in    sfixed(G_A_BITS - 1 downto -G_A_ACCURACY);
    s_b_x_i   : in    sfixed(G_B_BITS - 1 downto -G_B_ACCURACY);
    s_b_y_i   : in    sfixed(G_B_BITS - 1 downto -G_B_ACCURACY);

    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_res_x_o : out   sfixed(G_O_BITS - 1 downto -G_O_ACCURACY);
    m_res_y_o : out   sfixed(G_O_BITS - 1 downto -G_O_ACCURACY)
  );
end entity scalar_product;

architecture synthesis of scalar_product is

begin

  s_ready_o <= m_ready_i or not m_valid_o;

  res_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
      end if;

      if s_valid_i = '1' and s_ready_o = '1' then
        m_res_x_o <= resize(s_a_i * s_b_x_i, m_res_x_o,
                            round_style    => fixed_truncate,
                            overflow_style => fixed_wrap);
        m_res_y_o <= resize(s_a_i * s_b_y_i, m_res_y_o,
                            round_style    => fixed_truncate,
                            overflow_style => fixed_wrap);
        m_valid_o <= '1';
      end if;

      if rst_i = '1' then
        m_valid_o <= '0';
      end if;
    end if;
  end process res_proc;

end architecture synthesis;

