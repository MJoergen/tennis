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

-- Since the calculations are quite involved, some approximations are made along the way.
-- Furthermore, it is assumed that the radius is a power of two.

-- The formulae used are:
-- DP_vec = POS_vec - CENTER_vec
-- DP2 = DP_vec * DP_vec
-- R2 = RADIUS^2
-- P = V_vec * DP_vec
-- T = 2*P / DP2
-- V_NEW_vec = V_vec
-- if DP2 < R2
--   V_NEW_vec = V_vec - T * DP_vec
--
-- In order to avoid the division by DP2 when calculating T, we employ the following
-- approximation:
-- 1 / DP2 === 1 / R2 * (1 + (R2 - DP2)/R2)
-- which is good when DP2 is close to R2.
-- It can be assumed that dividing by R2 is easy, since the radius must be a power of two.

entity collision is
  generic (
    G_ACCURACY : natural;
    G_POS_BITS : natural;
    G_VEL_BITS : natural;
    G_RADIUS   : sfixed(G_POS_BITS - 1 downto -G_ACCURACY)
  );
  port (
    clk_i      : in    std_logic;
    rst_i      : in    std_logic;

    pos_x_i    : in    ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
    pos_y_i    : in    ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
    vel_x_i    : in    sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
    vel_y_i    : in    sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);

    center_x_i : in    ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
    center_y_i : in    ufixed(G_POS_BITS - 1 downto -G_ACCURACY);

    vel_x_o    : out   sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
    vel_y_o    : out   sfixed(G_VEL_BITS - 1 downto -G_ACCURACY)
  );
end entity collision;

architecture synthesis of collision is

  signal dp_x    : sfixed(G_POS_BITS downto -G_ACCURACY);
  signal dp_y    : sfixed(G_POS_BITS downto -G_ACCURACY);
  signal dp2     : sfixed(2 * G_POS_BITS downto -G_ACCURACY);
  signal r2      : sfixed(2 * G_POS_BITS downto -G_ACCURACY);
  signal p       : sfixed(2 * G_POS_BITS downto -G_ACCURACY);
  signal dp2_inv : sfixed(G_ACCURACY-1 downto -2 * G_POS_BITS);
  signal t       : sfixed(G_VEL_BITS + G_ACCURACY-1 downto -G_VEL_BITS - G_ACCURACY);

  pure function is_power_of_two (
    arg : sfixed(G_POS_BITS - 1 downto -G_ACCURACY)
  ) return boolean is
    variable val_v : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);
  begin
    val_v := to_sfixed(1.0, G_POS_BITS - 1, -G_ACCURACY);
    while val_v < arg loop
      val_v := resize(val_v * 2.0, val_v);
    end loop;
    return val_v = arg;
  end function;

begin

  assert is_power_of_two(G_RADIUS)
    report "Compile error: G_RADIUS (" & to_string(G_RADIUS) & ") must be a power of two";

  -- DP_vec = POS_vec - CENTER_vec
  dp_x <= resize(to_sfixed(pos_x_i) - to_sfixed(center_x_i), dp_x);
  dp_y <= resize(to_sfixed(pos_y_i) - to_sfixed(center_y_i), dp_y);

  -- DP2 = DP_vec * DP_vec
  dp2  <= resize(dp_x * dp_x + dp_y * dp_y, dp2);

  -- R2 = RADIUS^2
  r2   <= resize(G_RADIUS * G_RADIUS, r2);

  -- P = V_vec * DP_vec
  p    <= resize(vel_x_i * dp_x + vel_y_i * dp_y, p);

  -- 1 / DP2 === 1 / R2 * (1 + (R2 - DP2)/R2)
  dp2_inv <= resize((1 + (r2 - dp2) / r2) / r2, dp2_inv);

  -- T = 2*P / DP2
  t <= resize(2 * p * dp2_inv, t);

  vel_proc : process (all)
  begin
    -- V_NEW_vec = V_vec
    vel_x_o <= vel_x_i;
    vel_y_o <= vel_y_i;

    if dp2 < r2 then

      -- V_NEW_vec = V_vec - T * DP_vec
      vel_x_o <= resize(vel_x_i - t*dp_x, vel_x_o);
      vel_y_o <= resize(vel_y_i - t*dp_y, vel_x_o);
    end if;
  end process vel_proc;

end architecture synthesis;

