library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

-- This is a fairly generic collision handling block.
-- The concept is a circular object with a given position and radius, moving with a given
-- velocity.  On its path it encounters a stationary circular ball with a given center and
-- radius. This block will calculate the new velocity assuming completely elastic
-- collision.

-- The calculation essentially involves the projection of the velocity vector onto the
-- displacement vector, see https://en.wikipedia.org/wiki/Vector_projection
-- where "a" is the velocity vector and "b" is the displacement vector.
-- The trick to avoiding division is to convert "b" into a unit vector.
-- This can be done efficiently using the CORDIC algorithm, see unit_vector.vhd

-- DP2 is the length squared of the displacement vector. This is here calculated directly
-- using a DSP, but could alternatively have been calculated using the CORDIC algorithm,
-- although that would have involved an additional scaling step, and therefore be a
-- slightly more obscure implementation.

-- The formulae used are:
-- DP_vec = CENTER_vec - POS_vec               (displacement vector)
-- DPU_vec = DP_vec / len(DP_vec)              (unit vector)
-- DOT = V_vec * DPU_vec                       (dot product)
-- PROJ = DOT * DPU_vec                        (calculate projection)
-- R2 = RADIUS^2                               (length squared of radius)
-- DP2 = DP_vec * DP_vec                       (length squared of displacement vector)
-- V_NEW_vec = V_vec                           (assume no collision)
-- if DP2 < R2 and DOT >= 0                    (if collision)
--   V_NEW_vec = V_vec - 2 * PROJ              (  subtract twice the projection)

entity collision_disk is
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
    s_a_radius_i   : in    ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
    s_b_center_x_i : in    ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
    s_b_center_y_i : in    ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
    s_b_radius_i   : in    ufixed(G_POS_BITS - 1 downto -G_ACCURACY);

    m_ready_i      : in    std_logic;
    m_valid_o      : out   std_logic;
    m_a_vel_x_o    : out   sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
    m_a_vel_y_o    : out   sfixed(G_VEL_BITS - 1 downto -G_ACCURACY)
  );
end entity collision_disk;

architecture synthesis of collision_disk is

  type   state_type is (IDLE_ST, DP_ST, DOT_ST, PROJ_ST);
  signal state : state_type := IDLE_ST;

  signal vel_x : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal vel_y : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);

  signal dp_x : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal dp_y : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);

  signal sum_r  : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal sum_r2 : sfixed(2 * G_POS_BITS - 1 downto -G_ACCURACY);

  signal unit_s_ready : std_logic;
  signal unit_s_valid : std_logic;
  signal unit_s_x     : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal unit_s_y     : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal unit_m_ready : std_logic;
  signal unit_m_valid : std_logic;
  signal unit_m_x     : sfixed(1 downto -G_ACCURACY - G_POS_BITS);
  signal unit_m_y     : sfixed(1 downto -G_ACCURACY - G_POS_BITS);

  signal dot_s_ready : std_logic;
  signal dot_s_valid : std_logic;
  signal dot_s_a_x   : sfixed(1 downto -G_ACCURACY - G_POS_BITS);
  signal dot_s_a_y   : sfixed(1 downto -G_ACCURACY - G_POS_BITS);
  signal dot_s_b_x   : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal dot_s_b_y   : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal dot_m_ready : std_logic;
  signal dot_m_valid : std_logic;
  signal dot_m       : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);

  signal proj_s_ready : std_logic;
  signal proj_s_valid : std_logic;
  signal proj_s_a     : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal proj_s_b_x   : sfixed(1 downto -G_ACCURACY - G_POS_BITS);
  signal proj_s_b_y   : sfixed(1 downto -G_ACCURACY - G_POS_BITS);
  signal proj_m_ready : std_logic;
  signal proj_m_valid : std_logic;
  signal proj_m_x     : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal proj_m_y     : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);

  signal dp2_s_ready : std_logic;
  signal dp2_s_valid : std_logic;
  signal dp2_s_a_x   : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal dp2_s_a_y   : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal dp2_s_b_x   : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal dp2_s_b_y   : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal dp2_m_ready : std_logic;
  signal dp2_m_valid : std_logic;
  signal dp2_m_res   : sfixed(2 * G_POS_BITS - 1 downto -G_ACCURACY);

begin

  s_ready_o    <= (m_ready_i or not m_valid_o) when state = IDLE_ST else
                  '0';

  unit_s_x     <= dp_x;
  unit_s_y     <= dp_y;

  unit_m_ready <= '1';
  dot_m_ready  <= '1';
  proj_m_ready <= '1' when state = IDLE_ST else
                  dp2_m_valid;
  dp2_m_ready  <= '1' when state = IDLE_ST else
                  proj_m_valid;

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
      end if;

      if unit_s_ready = '1' then
        unit_s_valid <= '0';
      end if;

      if dot_s_ready = '1' then
        dot_s_valid <= '0';
      end if;

      if proj_s_ready = '1' then
        proj_s_valid <= '0';
      end if;

      if dp2_s_ready = '1' then
        dp2_s_valid <= '0';
      end if;

      case state is

        when IDLE_ST =>
          unit_s_valid <= '0';
          dp2_s_valid  <= '0';
          dot_s_valid  <= '0';
          proj_s_valid <= '0';

          -- Wait for s_valid_i
          if s_valid_i = '1' then
            vel_x        <= s_a_vel_x_i;
            vel_y        <= s_a_vel_y_i;
            -- DP_vec = CENTER_vec - POS_vec
            dp_x         <= resize(to_sfixed(s_b_center_x_i) - to_sfixed(s_a_pos_x_i), dp_x,
                                   round_style    => fixed_truncate,
                                   overflow_style => fixed_wrap);
            dp_y         <= resize(to_sfixed(s_b_center_y_i) - to_sfixed(s_a_pos_y_i), dp_y,
                                   round_style    => fixed_truncate,
                                   overflow_style => fixed_wrap);
            sum_r        <= resize(sfixed(s_a_radius_i) + sfixed(s_b_radius_i), sum_r,
                                   round_style    => fixed_truncate,
                                   overflow_style => fixed_wrap);

            -- DPU_vec = DP_vec / len(DP_vec)
            unit_s_valid <= '1';
            state        <= DP_ST;
          end if;

        when DP_ST =>
          -- R2 = RADIUS^2
          sum_r2 <= resize(sum_r * sum_r, sum_r2,
                           round_style    => fixed_truncate,
                           overflow_style => fixed_wrap);

          -- Wait for unit_m_valid
          if unit_m_valid = '1' then
            -- Calculate dot
            dot_s_a_x   <= unit_m_x;
            dot_s_a_y   <= unit_m_y;
            dot_s_b_x   <= vel_x;
            dot_s_b_y   <= vel_y;
            dot_s_valid <= '1';
            state       <= DOT_ST;
          end if;

        when DOT_ST =>
          -- Wait for dot_m_valid
          if dot_m_valid = '1' then
            if dot_m >= 0 then
              -- Calculate proj
              proj_s_a     <= dot_m;
              proj_s_b_x   <= unit_m_x;
              proj_s_b_y   <= unit_m_y;
              proj_s_valid <= '1';
              -- Calculate dp2
              dp2_s_a_x    <= dp_x;
              dp2_s_a_y    <= dp_y;
              dp2_s_b_x    <= dp_x;
              dp2_s_b_y    <= dp_y;
              dp2_s_valid  <= '1';
              state        <= PROJ_ST;
            else
              -- Ignore collision if already moving away.
              m_a_vel_x_o <= vel_x;
              m_a_vel_y_o <= vel_y;
              m_valid_o   <= '1';
              state       <= IDLE_ST;
            end if;
          end if;

        when PROJ_ST =>
          -- Wait for dp2_m_valid AND proj_m_valid
          if dp2_m_valid = '1' and proj_m_valid = '1' then
            if dp2_m_res < sum_r2 then
              --   V_NEW_vec = V_vec - 2 * PROJ
              m_a_vel_x_o <= resize(vel_x - 2 * proj_m_x, m_a_vel_x_o,
                                    round_style    => fixed_truncate,
                                    overflow_style => fixed_wrap);
              m_a_vel_y_o <= resize(vel_y - 2 * proj_m_y, m_a_vel_y_o,
                                    round_style    => fixed_truncate,
                                    overflow_style => fixed_wrap);
            else
              m_a_vel_x_o <= vel_x;
              m_a_vel_y_o <= vel_y;
            end if;
            m_valid_o <= '1';
            state     <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        m_valid_o <= '0';
        state     <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;


  -----------------------------------------
  -- DPU_vec = DP_vec / len(DP_vec)
  -----------------------------------------

  unit_vector_inst : entity work.unit_vector
    generic map (
      G_ACCURACY => G_ACCURACY,
      G_BITS     => G_POS_BITS
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => unit_s_ready,
      s_valid_i => unit_s_valid,
      s_x_i     => unit_s_x,
      s_y_i     => unit_s_y,
      m_ready_i => unit_m_ready,
      m_valid_o => unit_m_valid,
      m_x_o     => unit_m_x,
      m_y_o     => unit_m_y
    ); -- unit_vector : entity work.unit_vector


  -----------------------------------------
  -- DOT = V_vec * DPU_vec
  -----------------------------------------

  dot_product_dot_inst : entity work.dot_product
    generic map (
      G_A_BITS     => 2,
      G_A_ACCURACY => G_ACCURACY + G_POS_BITS,
      G_B_BITS     => G_VEL_BITS,
      G_B_ACCURACY => G_ACCURACY,
      G_O_BITS     => G_VEL_BITS,
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
      m_res_o   => dot_m
    ); -- dot_product_dot_inst : entity work.dot_product


  -----------------------------------------
  -- PROJ = DOT * DPU_vec
  -----------------------------------------

  scalar_product_inst : entity work.scalar_product
    generic map (
      G_A_BITS     => G_VEL_BITS,
      G_A_ACCURACY => G_ACCURACY,
      G_B_BITS     => 2,
      G_B_ACCURACY => G_ACCURACY + G_POS_BITS,
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


  -----------------------------------------
  -- DP2 = DP_vec * DP_vec
  -----------------------------------------

  dot_product_dp2_inst : entity work.dot_product
    generic map (
      G_A_BITS     => G_POS_BITS,
      G_A_ACCURACY => G_ACCURACY,
      G_B_BITS     => G_POS_BITS,
      G_B_ACCURACY => G_ACCURACY,
      G_O_BITS     => 2 * G_POS_BITS,
      G_O_ACCURACY => G_ACCURACY
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => dp2_s_ready,
      s_valid_i => dp2_s_valid,
      s_a_x_i   => dp2_s_a_x,
      s_a_y_i   => dp2_s_a_y,
      s_b_x_i   => dp2_s_a_x,
      s_b_y_i   => dp2_s_a_y,
      m_ready_i => dp2_m_ready,
      m_valid_o => dp2_m_valid,
      m_res_o   => dp2_m_res
    ); -- dot_product_dp2_inst : entity work.dot_product

end architecture synthesis;

