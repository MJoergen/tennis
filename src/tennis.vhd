library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

library work;
  use work.sprite_pkg.all;

entity tennis is
  generic (
    G_ACCURACY : natural;
    G_SCREEN_X : natural range 0 to 2047;
    G_SCREEN_Y : natural range 0 to 2047
  );
  port (
    clk_i       : in    std_logic;
    rst_i       : in    std_logic;
    ce_i        : in    std_logic;
    btn_left_i  : in    std_logic;
    btn_right_i : in    std_logic;
    sprites_o   : out   sprite_array_type
  );
end entity tennis;

architecture synthesis of tennis is

  constant C_BITMAP_PLAYER : bitmap_type   :=
  (
     0 => "00000000000111111111000000000000",
     1 => "00000000111111111111111000000000",
     2 => "00000111111111111111111111000000",
     3 => "00001111111111111111111111100000",
     4 => "00011111111111111111111111110000",
     5 => "00111111111111111111111111111000",
     6 => "00111111111111111111111111111000",
     7 => "00111111111111111111111111111000",
     8 => "01111111111111111111111111111100",
     9 => "01111111111111111111111111111100",
    10 => "01111111111111111111111111111100",
    11 => "11111111111111111111111111111110",
    12 => "11111111111111111111111111111110",
    13 => "11111111111111111111111111111110",
    14 => "11111111111111111111111111111110",
    15 => "11111111111111111111111111111110",
    16 => "00000000000000000000000000000000",
    17 => "00000000000000000000000000000000",
    18 => "00000000000000000000000000000000",
    19 => "00000000000000000000000000000000",
    20 => "00000000000000000000000000000000",
    21 => "00000000000000000000000000000000",
    22 => "00000000000000000000000000000000",
    23 => "00000000000000000000000000000000",
    24 => "00000000000000000000000000000000",
    25 => "00000000000000000000000000000000",
    26 => "00000000000000000000000000000000",
    27 => "00000000000000000000000000000000",
    28 => "00000000000000000000000000000000",
    29 => "00000000000000000000000000000000",
    30 => "00000000000000000000000000000000",
    31 => "00000000000000000000000000000000"
  );

  constant C_BITMAP_COMPUTER : bitmap_type := C_BITMAP_PLAYER;

  constant C_BITMAP_BALL : bitmap_type     :=
  (
     0 => "00000000000111111111000000000000",
     1 => "00000000111111111111111000000000",
     2 => "00000111111111111111111111000000",
     3 => "00001111111111111111111111100000",
     4 => "00011111111111111111111111110000",
     5 => "00111111111111111111111111111000",
     6 => "00111111111111111111111111111000",
     7 => "00111111111111111111111111111000",
     8 => "01111111111111111111111111111100",
     9 => "01111111111111111111111111111100",
    10 => "01111111111111111111111111111100",
    11 => "11111111111111111111111111111110",
    12 => "11111111111111111111111111111110",
    13 => "11111111111111111111111111111110",
    14 => "11111111111111111111111111111110",
    15 => "11111111111111111111111111111110",
    16 => "11111111111111111111111111111110",
    17 => "11111111111111111111111111111110",
    18 => "11111111111111111111111111111110",
    19 => "11111111111111111111111111111110",
    20 => "01111111111111111111111111111100",
    21 => "01111111111111111111111111111100",
    22 => "01111111111111111111111111111100",
    23 => "00111111111111111111111111111000",
    24 => "00111111111111111111111111111000",
    25 => "00111111111111111111111111111000",
    26 => "00011111111111111111111111110000",
    27 => "00001111111111111111111111100000",
    28 => "00000111111111111111111111000000",
    29 => "00000000111111111111111000000000",
    30 => "00000000000111111111000000000000",
    31 => "00000000000000000000000000000000"
  );

  constant C_SPRITE_PLAYER   : natural     := 0;
  constant C_SPRITE_COMPUTER : natural     := 1;
  constant C_SPRITE_BALL     : natural     := 2;

  constant C_SIZE_SPRITE : natural         := 32;

  constant C_POS_BITS : natural            := 12;
  constant C_VEL_BITS : natural            := 12;

  signal   player_x   : ufixed(C_POS_BITS - 1 downto - G_ACCURACY);
  signal   player_y   : ufixed(C_POS_BITS - 1 downto - G_ACCURACY);
  signal   computer_x : ufixed(C_POS_BITS - 1 downto - G_ACCURACY);
  signal   computer_y : ufixed(C_POS_BITS - 1 downto - G_ACCURACY);
  signal   ball_x     : ufixed(C_POS_BITS - 1 downto - G_ACCURACY);
  signal   ball_y     : ufixed(C_POS_BITS - 1 downto - G_ACCURACY);

  signal   ball_restart : std_logic;

--  attribute mark_debug : string;
--  attribute mark_debug of ce_i         : signal is "true";
--  attribute mark_debug of btn_left_i   : signal is "true";
--  attribute mark_debug of btn_right_i  : signal is "true";
--  attribute mark_debug of ball_x       : signal is "true";
--  attribute mark_debug of ball_y       : signal is "true";
--  attribute mark_debug of ball_restart : signal is "true";
--  attribute mark_debug of player_x     : signal is "true";
--  attribute mark_debug of player_y     : signal is "true";
--  attribute mark_debug_clock : string;
--  attribute mark_debug_clock of ce_i         : signal is "mega65r6_inst/clk_rst_inst/vga_clk_o";
--  attribute mark_debug_clock of btn_left_i   : signal is "mega65r6_inst/clk_rst_inst/vga_clk_o";
--  attribute mark_debug_clock of btn_right_i  : signal is "mega65r6_inst/clk_rst_inst/vga_clk_o";
--  attribute mark_debug_clock of ball_x       : signal is "mega65r6_inst/clk_rst_inst/vga_clk_o";
--  attribute mark_debug_clock of ball_y       : signal is "mega65r6_inst/clk_rst_inst/vga_clk_o";
--  attribute mark_debug_clock of ball_restart : signal is "mega65r6_inst/clk_rst_inst/vga_clk_o";
--  attribute mark_debug_clock of player_x     : signal is "mega65r6_inst/clk_rst_inst/vga_clk_o";
--  attribute mark_debug_clock of player_y     : signal is "mega65r6_inst/clk_rst_inst/vga_clk_o";

begin

  sprites_o(C_SPRITE_PLAYER)   <=
  (
    pos_x  => to_integer(unsigned(to_slv(player_x))),
    pos_y  => to_integer(unsigned(to_slv(player_y))),
    bitmap => C_BITMAP_PLAYER,
    color  => C_COLOR_GREEN,
    active => '1'
  );

  sprites_o(C_SPRITE_COMPUTER) <=
  (
    pos_x  => to_integer(unsigned(to_slv(computer_x))),
    pos_y  => to_integer(unsigned(to_slv(computer_y))),
    bitmap => C_BITMAP_COMPUTER,
    color  => C_COLOR_RED,
    active => '1'
  );

  sprites_o(C_SPRITE_BALL)     <=
  (
    pos_x  => to_integer(unsigned(to_slv(ball_x))),
    pos_y  => to_integer(unsigned(to_slv(ball_y))),
    bitmap => C_BITMAP_BALL,
    color  => C_COLOR_YELLOW,
    active => '1'
  );

  player_inst : entity work.player
    generic map (
      G_POS_BITS    => C_POS_BITS,
      G_VEL_BITS    => C_VEL_BITS,
      G_ACCURACY    => G_ACCURACY,
      G_SIZE_SPRITE => C_SIZE_SPRITE,
      G_SCREEN_X    => G_SCREEN_X,
      G_SCREEN_Y    => G_SCREEN_Y
    )
    port map (
      clk_i       => clk_i,
      rst_i       => rst_i,
      ce_i        => ce_i,
      btn_left_i  => btn_left_i,
      btn_right_i => btn_right_i,
      player_x_o  => player_x,
      player_y_o  => player_y
    );


  -- Instantiate ball movement
  ball_inst : entity work.ball
    generic map (
      G_POS_BITS => C_POS_BITS,
      G_VEL_BITS => C_VEL_BITS,
      G_ACCURACY => G_ACCURACY,
      G_SCREEN_X => G_SCREEN_X,
      G_SCREEN_Y => G_SCREEN_Y
    )
    port map (
      clk_i        => clk_i,
      rst_i        => rst_i or ball_restart,
      ce_i         => ce_i,
      player_x_i   => player_x,
      player_y_i   => player_y,
      computer_x_i => computer_x,
      computer_y_i => computer_y,
      ball_pos_x_o => ball_x,
      ball_pos_y_o => ball_y
    ); -- ball_inst : entity work.ball

  ball_restart_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      ball_restart <= '0';
      if ball_x < 0 or ball_x > G_SCREEN_X or ball_y < 0 or ball_y > G_SCREEN_Y then
        ball_restart <= '1';
      end if;
    end if;
  end process ball_restart_proc;

end architecture synthesis;

