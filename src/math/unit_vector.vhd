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
  subtype  ITER_TYPE is natural range 0 to G_ACCURACY + G_BITS;

  -- Scaling factor.
  -- This is computed as K = 1/sqrt((1+1)*(1+1/4)*(1+1/16)*(1+1/64)*...)
  constant C_COEF_K : real        := 0.6072529350088812561694;
  constant C_INIT_X : OUTPUT_TYPE := to_sfixed(C_COEF_K, 1, -G_ACCURACY - G_BITS);
  constant C_INIT_Y : OUTPUT_TYPE := to_sfixed(0.0,      1, -G_ACCURACY - G_BITS);

  type     state_type is (IDLE_ST, BUSY_ST);
  signal   state : state_type     := IDLE_ST;

  -- Rotate input vector
  signal   rot_in_s_ready : std_logic;
  signal   rot_in_s_valid : std_logic;
  signal   rot_in_s_x     : INPUT_TYPE;
  signal   rot_in_s_y     : INPUT_TYPE;
  signal   rot_in_s_sign  : std_logic;
  signal   rot_in_m_ready : std_logic;
  signal   rot_in_m_valid : std_logic;
  signal   rot_in_m_x     : INPUT_TYPE;
  signal   rot_in_m_y     : INPUT_TYPE;

  -- Rotate output vector
  signal   rot_out_s_ready : std_logic;
  signal   rot_out_s_valid : std_logic;
  signal   rot_out_s_x     : OUTPUT_TYPE;
  signal   rot_out_s_y     : OUTPUT_TYPE;
  signal   rot_out_s_sign  : std_logic;
  signal   rot_out_m_ready : std_logic;
  signal   rot_out_m_valid : std_logic;
  signal   rot_out_m_x     : OUTPUT_TYPE;
  signal   rot_out_m_y     : OUTPUT_TYPE;

  signal   iter     : natural range 0 to G_ACCURACY + G_BITS;
  signal   negate_x : std_logic;

  pure function to_sl (
    arg : boolean
  ) return std_logic is
  begin
    if arg then
      return '1';
    else
      return '0';
    end if;
  end function to_sl;

begin

  rot_in_m_ready  <= '1';
  rot_out_m_ready <= '1';

  s_ready_o       <= m_ready_i or not m_valid_o when state = IDLE_ST else
                     '0';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
      end if;

      if rot_in_s_ready = '1' then
        rot_in_s_valid <= '0';
      end if;

      if rot_out_s_ready = '1' then
        rot_out_s_valid <= '0';
      end if;

      case state is

        when IDLE_ST =>
          if s_valid_i = '1' then
            -- First step is to take the absolute value of the X-coordinate
            -- and remember the sign in 'negate_x'.
            if s_x_i >= 0 then
              rot_in_s_x <= resize(s_x_i, rot_in_s_x,
                                   round_style    => fixed_truncate,
                                   overflow_style => fixed_wrap);
              negate_x   <= '0';
            else
              rot_in_s_x <= resize(-s_x_i, rot_in_s_x,
                                   round_style    => fixed_truncate,
                                   overflow_style => fixed_wrap);
              negate_x   <= '1';
            end if;

            rot_in_s_y      <= resize(s_y_i, rot_in_s_y,
                                      round_style    => fixed_truncate,
                                      overflow_style => fixed_wrap);
            rot_in_s_sign   <= to_sl(s_y_i < 0);
            rot_in_s_valid  <= '1';

            rot_out_s_x     <= C_INIT_X;
            rot_out_s_y     <= C_INIT_Y;
            rot_out_s_sign  <= to_sl(s_y_i >= 0);
            rot_out_s_valid <= '1';

            iter            <= 0;
            state           <= BUSY_ST;
          end if;

        when BUSY_ST =>
          if rot_in_m_valid = '1' and rot_out_m_valid = '1' then
            -- In each step, rotate the input and output vectors in opposite directions
            rot_in_s_x      <= rot_in_m_x;
            rot_in_s_y      <= rot_in_m_y;
            rot_in_s_sign   <= to_sl(rot_in_m_y < 0);
            rot_in_s_valid  <= '1';

            rot_out_s_x     <= rot_out_m_x;
            rot_out_s_y     <= rot_out_m_y;
            rot_out_s_sign  <= to_sl(rot_in_m_y >= 0);
            rot_out_s_valid <= '1';

            if iter < G_ACCURACY + G_BITS then
              iter <= iter + 1;
            else
              m_x_o     <= rot_out_m_x;
              m_y_o     <= rot_out_m_y;
              -- Optionally negate output X coordinate if needed.
              if negate_x = '1' then
                m_x_o <= resize(-rot_out_m_x, m_x_o,
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


  -------------------------
  -- Rotate input vector
  -------------------------

  cordic_rotate_input_inst : entity work.cordic_rotate
    generic map (
      G_BITS     => G_BITS,
      G_ACCURACY => G_ACCURACY + G_BITS
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => rot_in_s_ready,
      s_valid_i => rot_in_s_valid,
      s_x_i     => rot_in_s_x,
      s_y_i     => rot_in_s_y,
      s_shift_i => natural(iter),
      s_sign_i  => rot_in_s_sign,
      m_ready_i => rot_in_m_ready,
      m_valid_o => rot_in_m_valid,
      m_x_o     => rot_in_m_x,
      m_y_o     => rot_in_m_y
    ); -- cordic_rotate_input_inst : entity work.cordic_rotate


  -------------------------
  -- Rotate output vector
  -------------------------

  cordic_rotate_output_inst : entity work.cordic_rotate
    generic map (
      G_BITS     => 2,
      G_ACCURACY => G_ACCURACY + G_BITS
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => rot_out_s_ready,
      s_valid_i => rot_out_s_valid,
      s_x_i     => rot_out_s_x,
      s_y_i     => rot_out_s_y,
      s_shift_i => natural(iter),
      s_sign_i  => rot_out_s_sign,
      m_ready_i => rot_out_m_ready,
      m_valid_o => rot_out_m_valid,
      m_x_o     => rot_out_m_x,
      m_y_o     => rot_out_m_y
    ); -- cordic_rotate_output_inst : entity work.cordic_rotate

end architecture synthesis;

