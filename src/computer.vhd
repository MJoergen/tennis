library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

entity computer is
  generic (
    G_POS_BITS    : natural;
    G_VEL_BITS    : natural;
    G_ACCURACY    : natural;
    G_VELOCITY    : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
    G_SIZE_SPRITE : natural;
    G_SCREEN_X    : natural range 0 to 4095;
    G_SCREEN_Y    : natural range 0 to 4095
  );
  port (
    clk_i        : in    std_logic;
    rst_i        : in    std_logic;
    ce_i         : in    std_logic;
    ball_x_i     : in    ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
    ball_y_i     : in    ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
    computer_x_o : out   ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
    computer_y_o : out   ufixed(G_POS_BITS - 1 downto -G_ACCURACY)
  );
end entity computer;

architecture synthesis of computer is

  -- The computer player aims a little to the right of the center. This causes
  -- the ball to bounce left, towards the player.
  constant C_OFFSET          : natural := G_SIZE_SPRITE / 16;
  constant C_INIT_COMPUTER_X : natural := 3 * G_SCREEN_X / 4;
  constant C_INIT_COMPUTER_Y : natural := G_SCREEN_Y - 1;

  signal   computer_x : ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal   computer_y : ufixed(G_POS_BITS - 1 downto -G_ACCURACY);

  signal   inc : std_logic;
  signal   dec : std_logic;

begin

  computer_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      inc <= '0';
      dec <= '0';

      if ce_i = '1' then
        if computer_x > ball_x_i + C_OFFSET and
           computer_x > (G_SCREEN_X + G_SIZE_SPRITE) / 2 then
          inc <= '1';
        end if;
        if computer_x < ball_x_i + C_OFFSET then
          dec <= '1';
        end if;
      end if;

      if inc = '1' and dec = '0' then
        computer_x <= resize(ufixed(sfixed(computer_x) - G_VELOCITY), computer_x);
      end if;

      if inc = '0' and dec = '1' then
        computer_x <= resize(ufixed(sfixed(computer_x) + G_VELOCITY), computer_x);
      end if;

      if rst_i = '1' then
        inc        <= '0';
        dec        <= '0';
        computer_x <= to_ufixed(C_INIT_COMPUTER_X, G_POS_BITS - 1, -G_ACCURACY);
        computer_y <= to_ufixed(C_INIT_COMPUTER_Y, G_POS_BITS - 1, -G_ACCURACY);
      end if;
    end if;
  end process computer_proc;

  computer_x_o <= computer_x;
  computer_y_o <= computer_y;

end architecture synthesis;

