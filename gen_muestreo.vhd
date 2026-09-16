--------------------------------------------------------------------------------
-- Archivo      : gen_muestreo.vhd
-- Proyecto     : Generador de señales de muestreo
-- Autores      : Angela Burbano y Elkin Leguizamon
-- Descripción  : Genera fsclk, latido y pert a partir de un único contador
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity gen_muestreo is

    generic (
        F_RELOJ : positive := 50_000_000; -- Frecuencia del reloj [Hz]
        FS      : positive := 1_000       -- Frecuencia de muestreo [Hz]
    );

    port (
        clk     : in  std_logic;
        n_rst   : in  std_logic;

        -- Selector de perturbación
        -- 00 -> r = 4
        -- 01 -> r = 8
        -- 10 -> r = 16
        -- 11 -> r = 32
        sel     : in  std_logic_vector(1 downto 0);

        -- Salidas
        fsclk   : out std_logic;
        latido  : out std_logic;
        pert    : out std_logic

    );

end entity gen_muestreo;


architecture rtl of gen_muestreo is

    constant DIV_FS : positive := F_RELOJ / FS;

    signal cuenta : integer range 0 to DIV_FS - 1 := 0;

    -- Contador de semiciclos de la perturbación
    signal n_semi : integer range 0 to 15 := 0;

    signal latido_r : std_logic := '0';
    signal pert_r   : std_logic := '0';


    function seleccion_r(s : std_logic_vector(1 downto 0))
        return integer is
    begin
        case s is
            when "00"   => return 4;
            when "01"   => return 8;
            when "10"   => return 16;
            when "11"   => return 32;
            when others => return 4;
        end case;
    end function;

begin

    proceso_muestreo : process(clk, n_rst)

        variable r_actual : integer;

    begin

        if n_rst = '0' then

            cuenta   <= 0;
            n_semi   <= 0;

            latido_r <= '0';
            pert_r   <= '0';

            fsclk    <= '0';

        elsif rising_edge(clk) then

            fsclk <= '0';

            r_actual := seleccion_r(sel);


            if cuenta = DIV_FS - 1 then

                cuenta <= 0;

                -- Pulso de un ciclo de reloj
                fsclk <= '1';


                latido_r <= not latido_r;


                if n_semi = (r_actual / 2) - 1 then

                    n_semi <= 0;
                    pert_r <= not pert_r;

                else

                    n_semi <= n_semi + 1;

                end if;

            else

                cuenta <= cuenta + 1;

            end if;

        end if;

    end process proceso_muestreo;

    latido <= latido_r;
    pert   <= pert_r;

end architecture rtl;
