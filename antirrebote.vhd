--------------------------------------------------------------------------------
-- Archivo      : antirrebote.vhd
-- Descripcion  : Circuito antirrebote para un pulsador activo en bajo (KEY[0])
--                y generador de un pulso de un solo ciclo de reloj al detectar
--                una pulsacion estable. Reset sincrono, dominio unico CLOCK_50.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity antirrebote is
    generic (
        F_RELOJ     : positive := 50_000_000; -- Frecuencia del reloj [Hz]
        T_ANTIRREB  : positive := 10_000      -- Tiempo de estabilizacion [us] (10 ms)
    );
    port (
        clk     : in  std_logic;
        n_rst   : in  std_logic;
        key_n   : in  std_logic;   -- Entrada cruda del pulsador, activa en bajo
        pulso   : out std_logic    -- Pulso de un ciclo al detectar pulsacion valida
    );
end entity antirrebote;

architecture rtl of antirrebote is

    constant CUENTA_MAX : positive := (F_RELOJ / 1_000_000) * T_ANTIRREB;

    signal sync1, sync2      : std_logic := '1';
    signal key_estable       : std_logic := '1';
    signal key_estable_prev  : std_logic := '1';
    signal cuenta             : integer range 0 to CUENTA_MAX := 0;

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if n_rst = '0' then

                sync1 <= '1';
                sync2 <= '1';
                key_estable      <= '1';
                key_estable_prev <= '1';
                cuenta <= 0;
                pulso  <= '0';

            else

                -- Sincronizacion de la entrada asincrona
                sync1 <= key_n;
                sync2 <= sync1;

                pulso <= '0';

                if sync2 /= key_estable then
                    if cuenta = CUENTA_MAX - 1 then
                        cuenta      <= 0;
                        key_estable <= sync2;
                    else
                        cuenta <= cuenta + 1;
                    end if;
                else
                    cuenta <= 0;
                end if;

                key_estable_prev <= key_estable;

                -- Flanco de bajada de la senal ya antirrebotada -> pulso de un ciclo
                if key_estable_prev = '1' and key_estable = '0' then
                    pulso <= '1';
                end if;

            end if;
        end if;
    end process;

end architecture rtl;