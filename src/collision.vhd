library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity collision is
  generic (
    G_MAX_POS : natural;
    G_MAX_VEL : natural;
    G_RADIUS  : natural range 0 to G_MAX_POS
  );
  port (
    clk_i      : in    std_logic;
    rst_i      : in    std_logic;
    ce_i       : in    std_logic;

    pos_x_i    : in    natural range 0 to G_MAX_POS;
    pos_y_i    : in    natural range 0 to G_MAX_POS;
    vel_x_i    : in    integer range -G_MAX_VEL to G_MAX_VEL;
    vel_y_i    : in    integer range -G_MAX_VEL to G_MAX_VEL;

    center_x_i : in    natural range 0 to G_MAX_POS;
    center_y_i : in    natural range 0 to G_MAX_POS;

    vel_x_o    : out   integer range -G_MAX_VEL to G_MAX_VEL;
    vel_y_o    : out   integer range -G_MAX_VEL to G_MAX_VEL
  );
end entity collision;

architecture synthesis of collision is

  signal dp_x : integer range -G_MAX_POS to G_MAX_POS;
  signal dp_y : integer range -G_MAX_POS to G_MAX_POS;
  signal dp2  : natural range 0 to 2 * G_MAX_POS * G_MAX_POS;

begin

  -- Vector from Center to Position
  dp_x <= pos_x_i - center_x_i;
  dp_y <= pos_y_i - center_y_i;

  dp2  <= dp_x * dp_x + dp_y * dp_y;

  vel_proc : process (all)
  begin
    -- assume no collision
    vel_x_o <= vel_x_i;
    vel_y_o <= vel_y_i;

    -- TBD
    if dp2 < G_RADIUS * G_RADIUS then
      vel_x_o <= -vel_x_i;
      vel_y_o <= -vel_y_i;
    end if;
  end process vel_proc;

end architecture synthesis;

