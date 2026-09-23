--------------------------------------------------------------------------------
-- Archivo      : hex7seg.vhd
-- Descripcion  : Decodificador combinacional de 4 bits a siete segmentos,
--                salida activa en bajo (comun en las tarjetas DE1).
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity hex7seg is
    port (
        hex_in : in  std_logic_vector(3 downto 0);
        seg_n  : out std_logic_vector(6 downto 0)  -- gfedcba, activo en bajo
    );
end entity hex7seg;

architecture rtl of hex7seg is
begin

    process(hex_in)
    begin
        case hex_in is
            when "0000" => seg_n <= "1000000"; -- 0
            when "0001" => seg_n <= "1111001"; -- 1
            when "0010" => seg_n <= "0100100"; -- 2
            when "0011" => seg_n <= "0110000"; -- 3
            when "0100" => seg_n <= "0011001"; -- 4
            when "0101" => seg_n <= "0010010"; -- 5
            when "0110" => seg_n <= "0000010"; -- 6
            when "0111" => seg_n <= "1111000"; -- 7
            when "1000" => seg_n <= "0000000"; -- 8
            when "1001" => seg_n <= "0010000"; -- 9
            when "1010" => seg_n <= "0001000"; -- A
            when "1011" => seg_n <= "0000011"; -- b
            when "1100" => seg_n <= "1000110"; -- C
            when "1101" => seg_n <= "0100001"; -- d
            when "1110" => seg_n <= "0000110"; -- E
            when "1111" => seg_n <= "0001110"; -- F
            when others => seg_n <= "1111111";
        end case;
    end process;

end architecture rtl;