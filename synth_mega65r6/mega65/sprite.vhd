library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.sprite_pkg.all;

entity sprite is
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;
    vsync_i   : in    std_logic;

    -- Sprites
    sprites_i : in    sprite_array_type;

    -- Display
    pixel_x_i : in    natural range 0 to 4095;
    pixel_y_i : in    natural range 0 to 4095;
    rgb_i     : in    std_logic_vector(23 downto 0);
    rgb_o     : out   std_logic_vector(23 downto 0)
  );
end entity sprite;

architecture synthesis of sprite is

  subtype  offset_type is natural range 0 to C_SIZE_SPRITE - 1;

  type     offset_vector_type is array (natural range <>) of offset_type;

  signal   active   : std_logic_vector(0 to C_NUM_SPRITES - 1);
  signal   offset_x : offset_vector_type(0 to C_NUM_SPRITES - 1);
  signal   offset_y : offset_vector_type(0 to C_NUM_SPRITES - 1);

begin

  --------------------------------------------------------
  -- Stage 1:
  -- Calculate which sprites are visible at this pixel
  --------------------------------------------------------

  stage1_proc : process (clk_i)
    variable pos_x_v  : natural range 0 to 4095;
    variable pos_y_v  : natural range 0 to 4095;
    variable active_v : std_logic;

  begin
    if rising_edge(clk_i) then
      for i in 0 to C_NUM_SPRITES - 1 loop                                -- Loop through each sprite
        pos_x_v   := sprites_i(i).pos_x;
        pos_y_v   := sprites_i(i).pos_y;
        active_v  := sprites_i(i).active;

        active(i) <= '0';
        if active_v = '1' then
          if pixel_x_i >= pos_x_v and pixel_x_i < pos_x_v + C_SIZE_SPRITE and
             pixel_y_i >= pos_y_v and pixel_y_i < pos_y_v + C_SIZE_SPRITE then
            active(i)   <= '1';
            offset_x(i) <= pixel_x_i - pos_x_v;
            offset_y(i) <= pixel_y_i - pos_y_v;
          end if;
        end if;
      end loop;

    end if;
  end process stage1_proc;


  --------------------------------------------------------
  -- Stage 2:
  -- Render visible sprites
  --------------------------------------------------------

  stage2_proc : process (clk_i)
    variable bitmap_v : bitmap_type;
    variable color_v  : std_logic_vector(23 downto 0);
  begin
    if rising_edge(clk_i) then
      rgb_o <= rgb_i;                                                     -- Default is transparent

      for i in 0 to C_NUM_SPRITES - 1 loop                                -- Loop through each sprite
        bitmap_v := sprites_i(i).bitmap;
        color_v  := sprites_i(i).color;

        if active(i) = '1' then
          if bitmap_v(offset_y(i))(C_SIZE_SPRITE - 1 - offset_x(i)) = '1' then
            rgb_o <= color_v;
          end if;
        end if;
      end loop;

    end if;
  end process stage2_proc;

end architecture synthesis;

