--------------------------------------------------------------------------------
-- Archivo      : spi_slave.vhd
-- Proyecto     : Taller 1 - Comunicacion SPI en FPGA DE1 - Loopback Maestro-Esclavo
-- Descripcion  : Esclavo SPI parametrizado. Sincroniza SCLK, MOSI y SS_N con dos
--                flip-flops en cascada y detecta flancos comparando dos muestras
--                consecutivas (nunca usa SCLK como reloj ni SS_N como reset).
--                Opera integramente en el dominio de CLOCK_50, reset sincrono.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_slave is
    generic (
        DATA_WIDTH  : positive := 8;
        CPOL        : std_logic := '0';
        CPHA        : std_logic := '0';
        MSB_FIRST   : boolean   := true;
        ID_ESCLAVO  : std_logic_vector(7 downto 0) := x"9A"
    );
    port (
        clk      : in  std_logic;
        n_rst    : in  std_logic;   -- Reset sincrono, activo en bajo

        sclk_i   : in  std_logic;   -- Senales asincronas provenientes del exterior
        mosi_i   : in  std_logic;
        ss_n_i   : in  std_logic;
        miso_o   : out std_logic;

        rx_data  : out std_logic_vector(DATA_WIDTH-1 downto 0); -- Dato recibido (= SW del maestro)
        valid    : out std_logic   -- Pulso de un ciclo: dato recibido valido
    );
end entity spi_slave;

architecture rtl of spi_slave is

    -- Sincronizadores de dos flip-flops en cascada (mitigan metaestabilidad)
    signal sclk_ff1, sclk_ff2, sclk_ff2_prev : std_logic := CPOL;
    signal mosi_ff1, mosi_ff2                : std_logic := '0';
    signal ss_n_ff1, ss_n_ff2, ss_n_ff2_prev  : std_logic := '1';

    type state_t is (IDLE, ACTIVE);
    signal state : state_t := IDLE;

    signal tx_reg        : std_logic_vector(DATA_WIDTH-1 downto 0) := ID_ESCLAVO;
    signal rx_reg         : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal rx_data_r      : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

    signal tx_index       : integer range 0 to DATA_WIDTH-1 := 0;
    signal rx_index        : integer range 0 to DATA_WIDTH-1 := 0;
    signal tx_preloaded    : std_logic := '0';

    signal miso_r          : std_logic := '0';
    signal valid_r         : std_logic := '0';

    function idx_inicial return integer is
    begin
        if MSB_FIRST then
            return DATA_WIDTH-1;
        else
            return 0;
        end if;
    end function;

    function idx_siguiente(i : integer) return integer is
    begin
        if MSB_FIRST then
            return i - 1;
        else
            return i + 1;
        end if;
    end function;

begin

    process(clk)
        variable leading, trailing : boolean;
        variable ss_falling, ss_rising : boolean;
    begin
        if rising_edge(clk) then

            if n_rst = '0' then

                sclk_ff1 <= CPOL; sclk_ff2 <= CPOL; sclk_ff2_prev <= CPOL;
                mosi_ff1 <= '0';  mosi_ff2 <= '0';
                ss_n_ff1 <= '1';  ss_n_ff2 <= '1';  ss_n_ff2_prev <= '1';

                state        <= IDLE;
                tx_reg       <= ID_ESCLAVO;
                rx_reg       <= (others => '0');
                rx_data_r    <= (others => '0');
                tx_index     <= idx_inicial;
                rx_index     <= idx_inicial;
                tx_preloaded <= '0';
                miso_r       <= '0';
                valid_r      <= '0';

            else

                -- Sincronizador de dos etapas
                sclk_ff1 <= sclk_i;
                sclk_ff2 <= sclk_ff1;
                sclk_ff2_prev <= sclk_ff2;

                mosi_ff1 <= mosi_i;
                mosi_ff2 <= mosi_ff1;

                ss_n_ff1 <= ss_n_i;
                ss_n_ff2 <= ss_n_ff1;
                ss_n_ff2_prev <= ss_n_ff2;

                valid_r <= '0';

                -- Deteccion de flancos comparando dos muestras consecutivas ya sincronizadas
                leading  := (sclk_ff2_prev = CPOL)     and (sclk_ff2 = not CPOL);
                trailing := (sclk_ff2_prev = not CPOL) and (sclk_ff2 = CPOL);
                ss_falling := (ss_n_ff2_prev = '1') and (ss_n_ff2 = '0');
                ss_rising  := (ss_n_ff2_prev = '0') and (ss_n_ff2 = '1');

                case state is

                    when IDLE =>
                        miso_r <= '0'; -- MISO a nivel conocido mientras SS_N esta en alto

                        if ss_falling then
                            tx_reg       <= ID_ESCLAVO;
                            tx_index     <= idx_inicial;
                            rx_index     <= idx_inicial;
                            state        <= ACTIVE;

                            if CPHA = '0' then
                                miso_r       <= ID_ESCLAVO(idx_inicial);
                                tx_preloaded <= '1';
                            else
                                tx_preloaded <= '0';
                            end if;
                        end if;

                    when ACTIVE =>
                        if ss_rising then
                            rx_data_r <= rx_reg;
                            valid_r   <= '1';
                            miso_r    <= '0';
                            state     <= IDLE;

                        elsif (leading and CPHA = '0') or (trailing and CPHA = '1') then
                            -- Flanco de muestreo: capturar MOSI
                            rx_reg(rx_index) <= mosi_ff2;
                            rx_index         <= idx_siguiente(rx_index);

                        elsif (trailing and CPHA = '0') or (leading and CPHA = '1') then
                            -- Flanco de cambio de dato: actualizar MISO
                            if tx_preloaded = '1' then
                                tx_index <= idx_siguiente(tx_index);
                                miso_r   <= tx_reg(idx_siguiente(tx_index));
                            else
                                miso_r       <= tx_reg(tx_index);
                                tx_preloaded <= '1';
                            end if;
                        end if;

                end case;

            end if;

        end if;
    end process;

    miso_o  <= miso_r;
    rx_data <= rx_data_r;
    valid   <= valid_r;

end architecture rtl;