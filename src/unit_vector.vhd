library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

-- This uses the CORDIC algorithm to calculate the unit vector

entity unit_vector is
  generic (
    G_ITERS    : natural;
    G_ACCURACY : natural;
    G_BITS     : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_x_i     : in    sfixed(G_BITS - 1 downto -G_ACCURACY);
    s_y_i     : in    sfixed(G_BITS - 1 downto -G_ACCURACY);

    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_x_o     : out   sfixed(G_BITS - 1 downto -G_ACCURACY);
    m_y_o     : out   sfixed(G_BITS - 1 downto -G_ACCURACY)
  );
end entity unit_vector;

architecture synthesis of unit_vector is

  constant C_COEF_K : real                                  := 0.6072529350088812561694;
  constant C_INIT_X : sfixed(G_BITS - 1 downto -G_ACCURACY) := to_sfixed(C_COEF_K, G_BITS - 1, -G_ACCURACY);
  constant C_INIT_Y : sfixed(G_BITS - 1 downto -G_ACCURACY) := to_sfixed(0.0, G_BITS - 1, -G_ACCURACY);

  signal   s_x : sfixed(G_BITS - 1 downto -G_ACCURACY);
  signal   s_y : sfixed(G_BITS - 1 downto -G_ACCURACY);

  signal   u_x : sfixed(G_BITS - 1 downto -G_ACCURACY);
  signal   u_y : sfixed(G_BITS - 1 downto -G_ACCURACY);

  signal   iter : natural range 0 to G_ITERS;

begin

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
      end if;

      if s_ready_o = '1' then
        if s_valid_i = '1' then
          s_x       <= s_x_i;
          s_y       <= s_y_i;
          u_x       <= C_INIT_X;
          u_y       <= C_INIT_Y;
          iter      <= 0;
          s_ready_o <= '0';
        end if;
      else
      end if;

      if rst_i = '1' then
        s_ready_o <= '1';
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;

