library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

-- This is a fairly generic collision handling block.
-- The concept is a circular object with a given position and radius, moving with a given
-- velocity.  On its path it encounters a stationary line (really a wall) with a given
-- position and a given normal vector (the normal vector points away from wall).  This
-- block will calculate the new velocity assuming completely elastic collision.

-- The normal vector is assumed to be a unit vector.

-- IDLE_ST:
--   DOT = NORMAL_vec * (POINT_vec - POS_vec)   (distance to line)

-- DP_ST:
--   DOT = NORMAL_vec * VEL_vec


entity collision_line is
  generic (
    G_ACCURACY : natural;
    G_POS_BITS : natural;
    G_VEL_BITS : natural
  );
  port (
    clk_i          : in    std_logic;
    rst_i          : in    std_logic;

    s_ready_o      : out   std_logic;
    s_valid_i      : in    std_logic;
    s_a_pos_x_i    : in    ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
    s_a_pos_y_i    : in    ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
    s_a_vel_x_i    : in    sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
    s_a_vel_y_i    : in    sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
    s_a_radius_i   : in    ufixed(G_POS_BITS - 1 downto 0);
    s_b_point_x_i  : in    ufixed(G_POS_BITS - 1 downto 0);
    s_b_point_y_i  : in    ufixed(G_POS_BITS - 1 downto 0);
    s_b_normal_x_i : in    sfixed(1 downto -G_ACCURACY);
    s_b_normal_y_i : in    sfixed(1 downto -G_ACCURACY);

    m_ready_i      : in    std_logic;
    m_valid_o      : out   std_logic;
    m_a_vel_x_o    : out   sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
    m_a_vel_y_o    : out   sfixed(G_VEL_BITS - 1 downto -G_ACCURACY)
  );
end entity collision_line;

architecture synthesis of collision_line is

  type   state_type is (IDLE_ST, DP_ST, DOT_ST, PROJ_ST);
  signal state : state_type := IDLE_ST;

  signal vel_x    : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal vel_y    : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal radius   : ufixed(G_POS_BITS - 1 downto 0);
  signal normal_x : sfixed(1 downto -G_ACCURACY);
  signal normal_y : sfixed(1 downto -G_ACCURACY);

  signal dot_s_ready : std_logic;
  signal dot_s_valid : std_logic;
  signal dot_s_a_x   : sfixed(1 downto -G_ACCURACY);
  signal dot_s_a_y   : sfixed(1 downto -G_ACCURACY);
  signal dot_s_b_x   : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal dot_s_b_y   : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal dot_m_ready : std_logic;
  signal dot_m_valid : std_logic;
  signal dot_m_res   : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);

  signal proj_s_ready : std_logic;
  signal proj_s_valid : std_logic;
  signal proj_s_a     : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal proj_s_b_x   : sfixed(1 downto -G_ACCURACY);
  signal proj_s_b_y   : sfixed(1 downto -G_ACCURACY);
  signal proj_m_ready : std_logic;
  signal proj_m_valid : std_logic;
  signal proj_m_x     : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal proj_m_y     : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);

begin

  s_ready_o    <= (m_ready_i or not m_valid_o) when state = IDLE_ST else
                  '0';

  dot_m_ready  <= '1';
  proj_m_ready <= '1';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
      end if;

      if dot_s_ready = '1' then
        dot_s_valid <= '0';
      end if;

      if proj_s_ready = '1' then
        proj_s_valid <= '0';
      end if;

      case state is

        when IDLE_ST =>
          -- Wait for s_valid_i
          if s_valid_i = '1' then
            vel_x       <= s_a_vel_x_i;
            vel_y       <= s_a_vel_y_i;
            radius      <= s_a_radius_i;
            normal_x    <= s_b_normal_x_i;
            normal_y    <= s_b_normal_y_i;

            dot_s_a_x   <= s_b_normal_x_i;
            dot_s_a_y   <= s_b_normal_y_i;
            -- DP_vec = CENTER_vec - POS_vec
            dot_s_b_x   <= resize(to_sfixed(s_a_pos_x_i) - to_sfixed(s_b_point_x_i), dot_s_b_x,
                                  round_style    => fixed_truncate,
                                  overflow_style => fixed_wrap);
            dot_s_b_y   <= resize(to_sfixed(s_a_pos_y_i) - to_sfixed(s_b_point_y_i), dot_s_b_y,
                                  round_style    => fixed_truncate,
                                  overflow_style => fixed_wrap);

            dot_s_valid <= '1';
            state       <= DP_ST;
          end if;

        when DP_ST =>
          if dot_m_valid = '1' then
            if dot_m_res >= sfixed(radius) or dot_m_res <= -sfixed(radius) then
              m_a_vel_x_o <= vel_x;
              m_a_vel_y_o <= vel_y;
              m_valid_o   <= '1';
              state       <= IDLE_ST;
            else
              dot_s_b_x   <= resize(vel_x, dot_s_b_x,
                                    round_style    => fixed_truncate,
                                    overflow_style => fixed_wrap);
              dot_s_b_y   <= resize(vel_y, dot_s_b_y,
                                    round_style    => fixed_truncate,
                                    overflow_style => fixed_wrap);
              dot_s_valid <= '1';
              state       <= DOT_ST;
            end if;
          end if;

        when DOT_ST =>
          if dot_m_valid = '1' then
            if dot_m_res >= 0 then
              -- If ball is already traveling away from wall, then don't bounce
              m_a_vel_x_o <= vel_x;
              m_a_vel_y_o <= vel_y;
              m_valid_o   <= '1';
              state       <= IDLE_ST;
            else
              proj_s_a     <= dot_m_res;
              proj_s_b_x   <= normal_x;
              proj_s_b_y   <= normal_y;
              proj_s_valid <= '1';
              state        <= PROJ_ST;
            end if;
          end if;

        when PROJ_ST =>
          if proj_m_valid = '1' then
            m_a_vel_x_o <= resize(vel_x - 2 * proj_m_x, m_a_vel_x_o,
                                  round_style    => fixed_truncate,
                                  overflow_style => fixed_wrap);
            m_a_vel_y_o <= resize(vel_y - 2 * proj_m_y, m_a_vel_y_o,
                                  round_style    => fixed_truncate,
                                  overflow_style => fixed_wrap);
            m_valid_o   <= '1';
            state       <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        m_valid_o <= '0';
        state     <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

  dot_product_inst : entity work.dot_product
    generic map (
      G_A_BITS     => 2,
      G_A_ACCURACY => G_ACCURACY,
      G_B_BITS     => G_POS_BITS,
      G_B_ACCURACY => G_ACCURACY,
      G_O_BITS     => G_POS_BITS,
      G_O_ACCURACY => G_ACCURACY
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => dot_s_ready,
      s_valid_i => dot_s_valid,
      s_a_x_i   => dot_s_a_x,
      s_a_y_i   => dot_s_a_y,
      s_b_x_i   => dot_s_b_x,
      s_b_y_i   => dot_s_b_y,
      m_ready_i => dot_m_ready,
      m_valid_o => dot_m_valid,
      m_res_o   => dot_m_res
    ); -- dot_product_inst : entity work.dot_product

  scalar_product_inst : entity work.scalar_product
    generic map (
      G_A_BITS     => G_POS_BITS,
      G_A_ACCURACY => G_ACCURACY,
      G_B_BITS     => 2,
      G_B_ACCURACY => G_ACCURACY,
      G_O_BITS     => G_VEL_BITS,
      G_O_ACCURACY => G_ACCURACY
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => proj_s_ready,
      s_valid_i => proj_s_valid,
      s_a_i     => proj_s_a,
      s_b_x_i   => proj_s_b_x,
      s_b_y_i   => proj_s_b_y,
      m_ready_i => proj_m_ready,
      m_valid_o => proj_m_valid,
      m_res_x_o => proj_m_x,
      m_res_y_o => proj_m_y
    ); -- scalar_product_inst : entity work.scalar_product

end architecture synthesis;

