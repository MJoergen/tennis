library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

-- This uses the CORDIC algorithm to calculate the unit vector.
--
-- The idea is that the algorithm "rotates" the input vector until it has an angle of
-- zero.  Simultaneously, it "rotates" another vector opposite, that has an initial angle
-- of zero.  Finally, since the "rotations" introduce a constant scaling factor of K =
-- 0.607, this scaling factor is introduced as the initial value of the second vector.
--
-- Each rotation is performed as a matrix multiplication by ((1, a), (-a, 1)), where
-- a = +/- 2^(-n). Such a rotation can be done by a barrel shifter and two adders.

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

  subtype  INPUT_TYPE is sfixed(G_BITS - 1 downto -G_ACCURACY - G_BITS);
  subtype  OUTPUT_TYPE is sfixed(1 downto -G_ACCURACY - G_BITS);

  -- Scaling factor.
  -- This is computed as K = 1/sqrt((1+1)*(1+1/4)*(1+1/16)*(1+1/64)*...)
  constant C_COEF_K : real        := 0.6072529350088812561694;
  constant C_INIT_X : OUTPUT_TYPE := to_sfixed(C_COEF_K, 1, -G_ACCURACY - G_BITS);
  constant C_INIT_Y : OUTPUT_TYPE := to_sfixed(0.0,      1, -G_ACCURACY - G_BITS);

  signal   s_x : INPUT_TYPE;
  signal   s_y : INPUT_TYPE;

  signal   s_x_shifted : INPUT_TYPE;
  signal   s_y_shifted : INPUT_TYPE;

  signal   s_x_inc : INPUT_TYPE;
  signal   s_y_inc : INPUT_TYPE;

  signal   s_x_new : INPUT_TYPE;
  signal   s_y_new : INPUT_TYPE;

  signal   m_x_shifted : OUTPUT_TYPE;
  signal   m_y_shifted : OUTPUT_TYPE;

  signal   m_x_inc : OUTPUT_TYPE;
  signal   m_y_inc : OUTPUT_TYPE;

  signal   m_x_new : OUTPUT_TYPE;
  signal   m_y_new : OUTPUT_TYPE;

  signal   iter     : natural range 0 to G_ACCURACY + G_BITS;
  signal   negate_x : std_logic;

  signal   s_in_ready  : std_logic;
  signal   s_in_valid  : std_logic;
  signal   s_out_ready : std_logic;
  signal   s_out_valid : std_logic;

  signal   m_in_ready  : std_logic;
  signal   m_in_valid  : std_logic;
  signal   m_out_ready : std_logic;
  signal   m_out_valid : std_logic;

  type     state_type is (IDLE_ST, BUSY_ST);
  signal   state : state_type     := IDLE_ST;

begin

  s_out_ready <= '1';
  m_out_ready <= '1';

  s_ready_o   <= m_ready_i or not m_valid_o when state = IDLE_ST else
                 '0';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
      end if;

      if s_in_ready = '1' then
        s_in_valid <= '0';
      end if;

      if m_in_ready = '1' then
        m_in_valid <= '0';
      end if;

      case state is

        when IDLE_ST =>
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

            s_y        <= resize(s_y_i, s_y,
                                 round_style    => fixed_truncate,
                                 overflow_style => fixed_wrap);
            s_in_valid <= '1';

            m_x_o      <= C_INIT_X;
            m_y_o      <= C_INIT_Y;
            m_in_valid <= '1';

            iter       <= 0;
            state      <= BUSY_ST;
          end if;

        when BUSY_ST =>
          if s_out_valid = '1' and m_out_valid = '1' then
            s_x        <= s_x_new;
            s_y        <= s_y_new;
            s_in_valid <= '1';

            m_x_o      <= m_x_new;
            m_y_o      <= m_y_new;
            m_in_valid <= '1';

            if iter < G_ACCURACY + G_BITS then
              iter <= iter + 1;
            else
              if negate_x = '1' then
                m_x_o <= resize(-m_x_new, m_x_o,
                                round_style    => fixed_truncate,
                                overflow_style => fixed_wrap);
              end if;
              state     <= IDLE_ST;
              m_valid_o <= '1';
            end if;
          end if;

      end case;

      if rst_i = '1' then
        state     <= IDLE_ST;
        m_valid_o <= '0';
      end if;
    end if;
  end process fsm_proc;

  shifter_s_inst : entity work.shifter
    generic map (
      G_REG      => true,
      G_ACCURACY => G_BITS,
      G_BITS     => G_BITS + G_ACCURACY
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => s_in_ready,
      s_valid_i => s_in_valid,
      s_x_i     => s_x,
      s_y_i     => s_y,
      s_shift_i => natural(iter),
      m_ready_i => s_out_ready,
      m_valid_o => s_out_valid,
      m_x_o     => s_x_shifted,
      m_y_o     => s_y_shifted
    ); -- shifter_s_inst : entity work.shifter

  shifter_m_inst : entity work.shifter
    generic map (
      G_REG      => true,
      G_ACCURACY => 2,
      G_BITS     => G_BITS + G_ACCURACY
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => m_in_ready,
      s_valid_i => m_in_valid,
      s_x_i     => m_x_o,
      s_y_i     => m_y_o,
      s_shift_i => natural(iter),
      m_ready_i => m_out_ready,
      m_valid_o => m_out_valid,
      m_x_o     => m_x_shifted,
      m_y_o     => m_y_shifted
    ); -- shifter_m_inst : entity work.shifter

  -- (x,y) = (x +- y*coef, y -+ x*coef)
  s_x_inc <= s_y_shifted when s_y >= 0 else
             resize(-s_y_shifted, s_x_inc,
                     round_style    => fixed_truncate,
                     overflow_style => fixed_wrap);

  s_y_inc <= resize(-s_x_shifted, s_y_inc,
                     round_style    => fixed_truncate,
                     overflow_style => fixed_wrap) when s_y >= 0 else
             s_x_shifted;

  adder_sx_inst : entity work.adder
    generic map (
      G_REG      => false,
      G_BITS     => G_BITS,
      G_ACCURACY => G_ACCURACY + G_BITS
    )
    port map (
      clk_i     => '0',
      rst_i     => '0',
      s_ready_o => open,
      s_valid_i => '1',
      s_a_i     => s_x,
      s_b_i     => s_x_inc,
      m_ready_i => '1',
      m_valid_o => open,
      m_res_o   => s_x_new
    ); -- adder_sx_inst : entity work.adder

  adder_sy_inst : entity work.adder
    generic map (
      G_REG      => false,
      G_BITS     => G_BITS,
      G_ACCURACY => G_ACCURACY + G_BITS
    )
    port map (
      clk_i     => '0',
      rst_i     => '0',
      s_ready_o => open,
      s_valid_i => '1',
      s_a_i     => s_y,
      s_b_i     => s_y_inc,
      m_ready_i => '1',
      m_valid_o => open,
      m_res_o   => s_y_new
    ); -- adder_sy_inst : entity work.adder

  -- (ux,uy) = (ux -+ uy*coef, uy +- ux*coef)
  m_x_inc <= resize(-m_y_shifted, m_x_inc,
                     round_style    => fixed_truncate,
                     overflow_style => fixed_wrap) when s_y >= 0 else
             m_y_shifted;

  m_y_inc <= m_x_shifted when s_y >= 0 else
             resize(-m_x_shifted, m_y_inc,
                     round_style    => fixed_truncate,
                     overflow_style => fixed_wrap);

  adder_mx_inst : entity work.adder
    generic map (
      G_REG      => false,
      G_BITS     => 2,
      G_ACCURACY => G_ACCURACY + G_BITS
    )
    port map (
      clk_i     => '0',
      rst_i     => '0',
      s_ready_o => open,
      s_valid_i => '1',
      s_a_i     => m_x_o,
      s_b_i     => m_x_inc,
      m_ready_i => '1',
      m_valid_o => open,
      m_res_o   => m_x_new
    ); -- adder_mx_inst : entity work.adder

  adder_my_inst : entity work.adder
    generic map (
      G_REG      => false,
      G_BITS     => 2,
      G_ACCURACY => G_ACCURACY + G_BITS
    )
    port map (
      clk_i     => '0',
      rst_i     => '0',
      s_ready_o => open,
      s_valid_i => '1',
      s_a_i     => m_y_o,
      s_b_i     => m_y_inc,
      m_ready_i => '1',
      m_valid_o => open,
      m_res_o   => m_y_new
    ); -- adder_my_inst : entity work.adder

end architecture synthesis;

