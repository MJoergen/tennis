library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

-- This uses the CORDIC algorithm to calculate the unit vector.

entity unit_vector is
  generic (
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
    m_x_o     : out   sfixed(1 downto -G_ACCURACY - G_BITS);
    m_y_o     : out   sfixed(1 downto -G_ACCURACY - G_BITS)
  );
end entity unit_vector;

architecture synthesis of unit_vector is

  constant C_COEF_K : real                                  := 0.6072529350088812561694;
  constant C_INIT_X : sfixed(1 downto -G_ACCURACY - G_BITS) := to_sfixed(C_COEF_K, 1, -G_ACCURACY - G_BITS);
  constant C_INIT_Y : sfixed(1 downto -G_ACCURACY - G_BITS) := to_sfixed(0.0,      1, -G_ACCURACY - G_BITS);

  signal   s_x : sfixed(G_BITS - 1 downto -G_ACCURACY - G_BITS);
  signal   s_y : sfixed(G_BITS - 1 downto -G_ACCURACY - G_BITS);

  signal   iter     : natural range 0 to G_ACCURACY + G_BITS;
  signal   negate_x : std_logic;

begin

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
        if m_valid_o = '1' then
          s_ready_o <= '1';
        end if;
      end if;

      if s_ready_o = '1' then
        if s_valid_i = '1' then
          if s_x_i >= 0 then
            s_x      <= resize(s_x_i, s_x,
                               round_style    => fixed_truncate,
                               overflow_style => fixed_wrap);
            negate_x <= '0';
          else
            s_x      <= resize(-s_x_i, s_x,
                               round_style    => fixed_truncate,
                               overflow_style => fixed_wrap);
            negate_x <= '1';
          end if;

          s_y       <= resize(s_y_i, s_y,
                              round_style    => fixed_truncate,
                              overflow_style => fixed_wrap);
          m_x_o     <= C_INIT_X;
          m_y_o     <= C_INIT_Y;
          iter      <= 0;
          s_ready_o <= '0';
        end if;
      elsif m_valid_o = '0' then
        if s_y > 0 then
          -- (x,y) = (x+y*coef, y-x*coef)
          s_x   <= resize(s_x + (s_y sra iter), s_x,
                          round_style    => fixed_truncate,
                          overflow_style => fixed_wrap);
          s_y   <= resize(s_y - (s_x sra iter), s_y,
                          round_style    => fixed_truncate,
                          overflow_style => fixed_wrap);

          -- (ux,uy) = (ux-uy*coef, uy+ux*coef)
          m_x_o <= resize(m_x_o - (m_y_o sra iter), m_x_o,
                          round_style    => fixed_truncate,
                          overflow_style => fixed_wrap);
          m_y_o <= resize(m_y_o + (m_x_o sra iter), m_y_o,
                          round_style    => fixed_truncate,
                          overflow_style => fixed_wrap);
        else
          -- (x,y) = (x-y*coef, y+x*coef)
          s_x   <= resize(s_x - (s_y sra iter), s_x,
                          round_style    => fixed_truncate,
                          overflow_style => fixed_wrap);
          s_y   <= resize(s_y + (s_x sra iter), s_y,
                          round_style    => fixed_truncate,
                          overflow_style => fixed_wrap);

          -- (ux,uy) = (ux+uy*coef, uy-ux*coef)
          m_x_o <= resize(m_x_o + (m_y_o sra iter), m_x_o,
                          round_style    => fixed_truncate,
                          overflow_style => fixed_wrap);
          m_y_o <= resize(m_y_o - (m_x_o sra iter), m_y_o,
                          round_style    => fixed_truncate,
                          overflow_style => fixed_wrap);
        end if;

        if iter < G_ACCURACY + G_BITS then
          iter <= iter + 1;
        else
          if negate_x = '1' then
            if s_y > 0 then
              m_x_o <= resize(-m_x_o + (m_y_o sra iter), m_x_o,
                              round_style    => fixed_truncate,
                              overflow_style => fixed_wrap);
            else
              m_x_o <= resize(-m_x_o - (m_y_o sra iter), m_x_o,
                              round_style    => fixed_truncate,
                              overflow_style => fixed_wrap);
            end if;
          end if;
          m_valid_o <= '1';
        end if;
      end if;

      if rst_i = '1' then
        s_ready_o <= '1';
        m_valid_o <= '0';
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;

