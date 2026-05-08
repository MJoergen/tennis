library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

-- This is a fairly generic collision handling block.
-- The concept is a point object with a given position and moving with a given velocity.
-- On its path it encounters a stationary circular ball with a given center and a constant
-- radius. This block will calculate the new velocity assuming completely elastic
-- collision.

-- The calculation essentially involves the projection of the velocity vector onto the
-- displacement vector, see https://en.wikipedia.org/wiki/Vector_projection
-- where "a" is the velocity vector and "b" is the displacement vector.
-- The trick to avoiding division is to convert "b" into a unit vector.
-- This can be done efficiently using the CORDIC algorithm, see unit_vector.vhd
-- The actual projected vector is not stored, but appears as the term "DOT * DPU_vec"
-- below.

-- DP2 is the length squared of the displacement vector. This is here calculated directly
-- using a DSP, but could alternatively have been calculated using the CORDIC algorithm,
-- although that would have involved an additional scaling step, and therefore be a
-- slightly more obscure implementation.

-- The formulae used are:
-- DP_vec = CENTER_vec - POS_vec               (displacement vector)
-- DPU_vec = DP_vec / len(DP_vec)              (unit vector)
-- DOT = V_vec * DPU_vec                       (dot product)
-- R2 = RADIUS^2                               (length squared of radius)
-- DP2 = DP_vec * DP_vec                       (length squared of displacement vector)
-- V_NEW_vec = V_vec                           (assume no collision)
-- if DP2 < R2                                 (if collision)
--   V_NEW_vec = V_vec - 2 * DOT * DPU_vec     (  subtract twice the projection)

entity collision is
  generic (
    G_ACCURACY : natural;
    G_POS_BITS : natural;
    G_VEL_BITS : natural;
    G_RADIUS   : sfixed(G_POS_BITS - 1 downto -G_ACCURACY)
  );
  port (
    clk_i        : in    std_logic;
    rst_i        : in    std_logic;

    s_ready_o    : out   std_logic;
    s_valid_i    : in    std_logic;
    s_pos_x_i    : in    ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
    s_pos_y_i    : in    ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
    s_vel_x_i    : in    sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
    s_vel_y_i    : in    sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
    s_center_x_i : in    ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
    s_center_y_i : in    ufixed(G_POS_BITS - 1 downto -G_ACCURACY);

    m_ready_i    : in    std_logic;
    m_valid_o    : out   std_logic;
    m_vel_x_o    : out   sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
    m_vel_y_o    : out   sfixed(G_VEL_BITS - 1 downto -G_ACCURACY)
  );
end entity collision;

architecture synthesis of collision is

  type     state_type is (IDLE_ST, DP_ST, DOT_ST);
  signal   state : state_type                                   := IDLE_ST;

  signal   vel_x : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal   vel_y : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);

  signal   dp_x : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal   dp_y : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);

  signal   dp2 : sfixed(2 * G_POS_BITS - 1 downto -G_ACCURACY);

  signal   dp_unit_s_ready : std_logic;
  signal   dp_unit_s_valid : std_logic;
  signal   dp_unit_s_x     : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal   dp_unit_s_y     : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);

  signal   dp_unit_m_ready : std_logic;
  signal   dp_unit_m_valid : std_logic;
  signal   dp_unit_m_x     : sfixed(0 downto -G_ACCURACY-G_POS_BITS);
  signal   dp_unit_m_y     : sfixed(0 downto -G_ACCURACY-G_POS_BITS);

  signal   dot : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);

  -- R2 = RADIUS^2
  constant C_R2 : sfixed(2 * G_POS_BITS - 1 downto -G_ACCURACY) := resize(G_RADIUS * G_RADIUS, 2 * G_POS_BITS - 1, -G_ACCURACY);

begin

  s_ready_o       <= (m_valid_o or not m_ready_i) when state = IDLE_ST else
                     '0';

  dp_unit_s_x     <= dp_x;
  dp_unit_s_y     <= dp_y;

  dp_unit_m_ready <= '1' when state = DOT_ST else
                     '0';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
      end if;

      if dp_unit_s_ready = '1' then
        dp_unit_s_valid <= '0';
      end if;

      case state is

        when IDLE_ST =>
          if s_valid_i = '1' then
            assert dp_unit_m_valid = '0';
            vel_x           <= s_vel_x_i;
            vel_y           <= s_vel_y_i;
            -- DP_vec = CENTER_vec - POS_vec
            dp_x            <= resize(to_sfixed(s_center_x_i) - to_sfixed(s_pos_x_i), dp_x);
            dp_y            <= resize(to_sfixed(s_center_y_i) - to_sfixed(s_pos_y_i), dp_y);
            -- DPU_vec = DP_vec / len(DP_vec)
            dp_unit_s_valid <= '1';
            state           <= DP_ST;
          end if;

        when DP_ST =>
          if dp_unit_m_valid = '1' then
            -- DP2 = DP_vec * DP_vec
            dp2   <= resize(dp_x * dp_x + dp_y * dp_y, dp2);
            -- DOT = V_vec * DPU_vec
            dot   <= resize(dp_unit_m_x * vel_x + dp_unit_m_y * vel_y, dot);
            state <= DOT_ST;
          end if;

        when DOT_ST =>
          if dp2 < C_R2 then
            --   V_NEW_vec = V_vec - 2 * DOT * DPU_vec
            m_vel_x_o <= resize(vel_x - 2 * dot * dp_unit_m_x, m_vel_x_o);
            m_vel_y_o <= resize(vel_y - 2 * dot * dp_unit_m_y, m_vel_y_o);
          else
            m_vel_x_o <= vel_x;
            m_vel_y_o <= vel_y;
          end if;
          m_valid_o <= '1';
          state     <= IDLE_ST;

      end case;

      if rst_i = '1' then
        state <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;


  -- DPU_vec = DP_vec / len(DP_vec)
  unit_vector_inst : entity work.unit_vector
    generic map (
      G_ITERS    => G_ACCURACY + G_POS_BITS,
      G_ACCURACY => G_ACCURACY,
      G_BITS     => G_POS_BITS
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => dp_unit_s_ready,
      s_valid_i => dp_unit_s_valid,
      s_x_i     => dp_unit_s_x,
      s_y_i     => dp_unit_s_y,
      m_ready_i => dp_unit_m_ready,
      m_valid_o => dp_unit_m_valid,
      m_x_o     => dp_unit_m_x,
      m_y_o     => dp_unit_m_y
    ); -- unit_vector : entity work.unit_vector

end architecture synthesis;

